import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { DependencyUnavailableError, DomainError } from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AppleTokenTypeHint } from '../../../integrations/apple/apple-token-revocation-port.js';
import type {
  AppleIdentityProof,
  AppleTokenVerifierPort,
} from '../../../integrations/apple/apple-token-verifier-port.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import type { SecretCipherPort } from '../../access/application/secret-cipher-port.js';
import { AppleProofInvalidError, SessionRevokedError } from '../../access/domain/access-errors.js';
import { AppleProofRequiredError } from '../domain/account-errors.js';
import type {
  AccountDeletionRepositoryPort,
  CreatorAppleCredentials,
} from './account-deletion-ports.js';

export interface DeleteOwnAccountCommand {
  /** Somente para o Criador sem refresh token Apple guardado (SPEC-022 §5.1). */
  readonly apple?: AppleIdentityProof;
}

interface PendingRevocation {
  readonly tokenEncrypted: string;
  readonly tokenTypeHint: AppleTokenTypeHint;
  readonly source: 'stored' | 'proof';
}

async function translateDependencyFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) throw error;
    throw new DependencyUnavailableError();
  }
}

/**
 * `DeleteOwnAccount` (UC20, SPEC-022 CA-01–CA-13).
 *
 * O alvo é sempre o titular da sessão (RNF06). Perfil não-Criador é anonimizado
 * e preserva o histórico como "Membro removido" (RN69). O Criador exclui a
 * família inteira; o token Apple guardado, ou o obtido de uma prova nova, entra
 * na fila de revogação no mesmo commit e é revogado depois dele (RN70, BA-40).
 */
export class DeleteOwnAccountUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccountDeletionRepositoryPort;
      readonly tokenVerifier: AppleTokenVerifierPort;
      readonly crypto: Pick<AccessCryptoPort, 'newId' | 'hashAppleSubject' | 'hashesMatch'>;
      readonly secretCipher: SecretCipherPort;
      readonly appleTokenRevoker: { processNow(id: string): Promise<void> };
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(actor: ActorContext, command: DeleteOwnAccountCommand = {}): Promise<void> {
    if (actor.isFamilyCreator) {
      await this.deleteFamily(actor, command.apple);
      return;
    }
    await this.deleteMember(actor);
  }

  private async deleteMember(actor: ActorContext): Promise<void> {
    const role = await translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const member = await this.deps.repository.findActiveMember(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
        });
        // Removido ou excluído enquanto aguardava o lock: a sessão já foi revogada
        // por quem chegou primeiro (CA-19).
        if (member === undefined || member.isFamilyCreator) throw new SessionRevokedError();
        await this.deps.repository.deleteMemberAccount(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
          now: this.deps.clock.now(),
        });
        return member.role;
      }),
    );

    this.deps.logger.info('account_deleted', { role, actor: 'self', familyDeleted: false });
  }

  private async deleteFamily(
    actor: ActorContext,
    proof: AppleIdentityProof | undefined,
  ): Promise<void> {
    const credentials = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findCreatorAppleCredentials(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
        }),
      ),
    );
    if (credentials === undefined) throw new SessionRevokedError();

    // A troca da prova com a Apple ocorre antes da transação (BA-40): falha de
    // rede ou recusa impede a exclusão sem alterar dados (CA-11).
    const revocation = await this.resolveRevocation(credentials, proof);
    const revocationId = revocation === undefined ? undefined : this.deps.crypto.newId();

    const { memberCount } = await translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const member = await this.deps.repository.findActiveMember(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
        });
        if (member === undefined || !member.isFamilyCreator) throw new SessionRevokedError();

        if (revocation !== undefined && revocationId !== undefined) {
          await this.deps.repository.enqueueAppleTokenRevocation(tx, {
            id: revocationId,
            tokenEncrypted: revocation.tokenEncrypted,
            tokenTypeHint: revocation.tokenTypeHint,
            now: this.deps.clock.now(),
          });
        }

        return this.deps.repository.deleteFamily(tx, {
          familyId: actor.familyId,
          creatorIdentityId: credentials.creatorIdentityId,
        });
      }),
    );

    this.deps.logger.info('family_deleted', {
      memberCount,
      appleTokenSource: revocation?.source ?? 'none',
    });

    // Tentativa imediata pós-commit; falhas ficam com o worker (CA-13).
    if (revocationId !== undefined) {
      await this.deps.appleTokenRevoker.processNow(revocationId);
    }
  }

  private async resolveRevocation(
    credentials: CreatorAppleCredentials,
    proof: AppleIdentityProof | undefined,
  ): Promise<PendingRevocation | undefined> {
    if (proof === undefined) {
      if (credentials.refreshTokenEncrypted === undefined) throw new AppleProofRequiredError();
      return {
        tokenEncrypted: credentials.refreshTokenEncrypted,
        tokenTypeHint: 'refresh_token',
        source: 'stored',
      };
    }

    let verified;
    try {
      verified = await this.deps.tokenVerifier.verifyIdentityProof(proof);
    } catch (error) {
      this.deps.logger.warn('account_deletion_apple_proof_rejected', {
        reason: error instanceof Error ? error.message : 'unknown_verification_failure',
      });
      throw new AppleProofInvalidError();
    }

    const subjectHash = this.deps.crypto.hashAppleSubject(verified.subject);
    if (!this.deps.crypto.hashesMatch(subjectHash, credentials.appleSubjectHash)) {
      this.deps.logger.warn('account_deletion_apple_proof_rejected', {
        reason: 'subject_mismatch',
      });
      throw new AppleProofInvalidError();
    }

    if (verified.refreshToken !== undefined) {
      return {
        tokenEncrypted: this.deps.secretCipher.encrypt(verified.refreshToken),
        tokenTypeHint: 'refresh_token',
        source: 'proof',
      };
    }
    if (credentials.refreshTokenEncrypted !== undefined) {
      return {
        tokenEncrypted: credentials.refreshTokenEncrypted,
        tokenTypeHint: 'refresh_token',
        source: 'stored',
      };
    }
    if (verified.accessToken !== undefined) {
      return {
        tokenEncrypted: this.deps.secretCipher.encrypt(verified.accessToken),
        tokenTypeHint: 'access_token',
        source: 'proof',
      };
    }

    // Prova válida sem token algum para revogar: a exclusão segue (a identidade
    // foi confirmada) e o fato fica registrado para acompanhamento.
    this.deps.logger.warn('apple_token_revocation_skipped', { reason: 'no_token_available' });
    return undefined;
  }
}
