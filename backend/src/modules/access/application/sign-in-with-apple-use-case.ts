import type { Clock } from '../../../shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AppleTokenVerifierPort } from '../../../integrations/apple/apple-token-verifier-port.js';
import { AppleProofInvalidError } from '../domain/access-errors.js';
import { ACCESS_TOKEN_TTL_MS } from './access-token-ttl.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort, CreatorMembershipRecord } from './access-repository-port.js';
import type { SignInWithAppleCommand, SignInWithAppleResult } from './sign-in-with-apple-dto.js';

/** `creationGrant` de 10 minutos (BA-21, CA-02). */
const CREATION_GRANT_TTL_MS = 10 * 60 * 1000;

const SESSION_REPLACED_REASON = 'replaced_by_new_apple_sign_in';

/**
 * `SignInWithApple` (UC04, SPEC-001 Fase 1).
 *
 * Valida a prova Apple e devolve a sessão do Criador quando a identidade já tem
 * família vinculada (CA-01), ou um grant restrito de criação quando não tem
 * (CA-02). A identidade nova é persistida na primeira autenticação, para que o
 * grant tenha a quem se vincular.
 */
export class SignInWithAppleUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccessRepositoryPort;
      readonly tokenVerifier: AppleTokenVerifierPort;
      readonly crypto: AccessCryptoPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: SignInWithAppleCommand): Promise<SignInWithAppleResult> {
    const identity = await this.verifyProof(command);

    const appleSubjectHash = this.deps.crypto.hashAppleSubject(identity.subject);
    const installationProofHash = this.deps.crypto.hashToken(command.installationProof);
    const now = this.deps.clock.now();

    // Uma transação cobre todo o caminho: a revogação da sessão anterior e a
    // abertura da nova precisam do mesmo commit (CA-05, RN44).
    return this.deps.transactionRunner.run(async (tx) => {
      const creatorIdentity =
        (await this.deps.repository.findCreatorIdentityByAppleSubjectHash(tx, appleSubjectHash)) ??
        (await this.deps.repository.insertCreatorIdentity(tx, {
          identityId: this.deps.crypto.newId(),
          appleSubjectHash,
          appleSubjectEncrypted: this.deps.crypto.encryptAppleSubject(identity.subject),
        }));

      // A família vem exclusivamente deste vínculo persistido; nada do comando
      // participa da decisão (CA-06, RNF06).
      const membership = await this.deps.repository.findCreatorMembership(tx, creatorIdentity.id);

      if (membership === undefined) {
        return this.issueCreationGrant(tx, {
          creatorIdentityId: creatorIdentity.id,
          installationProofHash,
          now,
        });
      }

      return this.issueSession(tx, { membership, installationProofHash, now });
    });
  }

  /**
   * Qualquer falha de verificação vira o mesmo erro: a resposta não revela qual
   * etapa reprovou a prova (CA-04).
   */
  private async verifyProof(
    command: SignInWithAppleCommand,
  ): Promise<{ readonly subject: string }> {
    try {
      return await this.deps.tokenVerifier.verifyIdentityProof({
        identityToken: command.identityToken,
        authorizationCode: command.authorizationCode,
        rawNonce: command.rawNonce,
      });
    } catch (error) {
      // `reason` é a mensagem do verificador, que por contrato não contém a
      // prova; os tokens em si nunca entram no log (RNF08, RNF16).
      this.deps.logger.warn('apple_sign_in_rejected', {
        reason: error instanceof Error ? error.message : 'unknown_verification_failure',
      });

      throw new AppleProofInvalidError();
    }
  }

  private async issueCreationGrant(
    tx: TransactionContext,
    params: {
      readonly creatorIdentityId: string;
      readonly installationProofHash: string;
      readonly now: Date;
    },
  ): Promise<SignInWithAppleResult> {
    const creationGrant = this.deps.crypto.generateOpaqueToken();
    const expiresAt = new Date(params.now.getTime() + CREATION_GRANT_TTL_MS);

    await this.deps.repository.insertCreationGrant(tx, {
      grantId: this.deps.crypto.newId(),
      creatorIdentityId: params.creatorIdentityId,
      grantTokenHash: this.deps.crypto.hashToken(creationGrant),
      installationProofHash: params.installationProofHash,
      expiresAt,
    });

    this.deps.logger.info('apple_sign_in_succeeded', { outcome: 'creationGrant' });

    return {
      outcome: 'creationGrant',
      creationGrant,
      expiresAt: expiresAt.toISOString(),
    };
  }

  private async issueSession(
    tx: TransactionContext,
    params: {
      readonly membership: CreatorMembershipRecord;
      readonly installationProofHash: string;
      readonly now: Date;
    },
  ): Promise<SignInWithAppleResult> {
    const { membership } = params;

    // Antes de inserir: o índice único parcial de sessão ativa por membro
    // recusaria a nova sessão enquanto a anterior existisse.
    const revokedSessionIds = await this.deps.repository.revokeActiveSessionsForMember(tx, {
      memberId: membership.memberId,
      reason: SESSION_REPLACED_REASON,
    });

    for (const sessionId of revokedSessionIds) {
      this.deps.logger.info('session_revoked', {
        sessionId,
        reason: SESSION_REPLACED_REASON,
      });
    }

    const sessionId = this.deps.crypto.newId();
    const accessToken = this.deps.crypto.generateOpaqueToken();
    const refreshToken = this.deps.crypto.generateOpaqueToken();
    const accessTokenExpiresAt = new Date(params.now.getTime() + ACCESS_TOKEN_TTL_MS);

    await this.deps.repository.insertSession(tx, {
      sessionId,
      familyId: membership.familyId,
      memberId: membership.memberId,
      refreshTokenHash: this.deps.crypto.hashToken(refreshToken),
      installationProofHash: params.installationProofHash,
    });

    await this.deps.repository.insertAccessToken(tx, {
      accessTokenId: this.deps.crypto.newId(),
      sessionId,
      tokenHash: this.deps.crypto.hashToken(accessToken),
      expiresAt: accessTokenExpiresAt,
    });

    this.deps.logger.info('apple_sign_in_succeeded', {
      outcome: 'session',
      familyId: membership.familyId,
    });

    return {
      outcome: 'session',
      sessionId,
      memberId: membership.memberId,
      familyId: membership.familyId,
      role: membership.role,
      isFamilyCreator: membership.isFamilyCreator,
      accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
      refreshToken,
    };
  }
}
