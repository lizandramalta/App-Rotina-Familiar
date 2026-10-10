import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort } from './access-repository-port.js';

/** Access token de 15 minutos (BA-10). */
const ACCESS_TOKEN_TTL_MS = 15 * 60 * 1000;

const SESSION_REPLACED_REASON = 'replaced_by_new_apple_sign_in';

export interface IssuedSession {
  readonly sessionId: string;
  readonly memberId: string;
  readonly familyId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly accessToken: string;
  readonly accessTokenExpiresAt: string;
  readonly refreshToken: string;
}

/**
 * Abre a sessão própria do membro (BA-10). Compartilhado entre o login Apple e a
 * criação de família, para que os dois emitam sessão pelo mesmo caminho: revoga
 * a anterior, grava o hash dos tokens e devolve os tokens brutos uma única vez.
 *
 * Exige a transação do chamador: a sessão só existe se o restante do comando
 * (por exemplo, a família) for confirmado junto.
 */
export class SessionIssuer {
  constructor(
    private readonly deps: {
      readonly repository: AccessRepositoryPort;
      readonly crypto: AccessCryptoPort;
      readonly logger: Logger;
    },
  ) {}

  public async issue(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly role: MemberRole;
      readonly isFamilyCreator: boolean;
      readonly installationProofHash: string;
      readonly now: Date;
      /** Motivo gravado nas sessões do membro que a nova substitui. */
      readonly replacedReason?: string;
    },
  ): Promise<IssuedSession> {
    // Antes de inserir: o índice único parcial de sessão ativa por membro
    // recusaria a nova sessão enquanto a anterior existisse.
    const reason = params.replacedReason ?? SESSION_REPLACED_REASON;
    const revokedSessionIds = await this.deps.repository.revokeActiveSessionsForMember(tx, {
      memberId: params.memberId,
      reason,
    });

    for (const sessionId of revokedSessionIds) {
      this.deps.logger.info('session_revoked', {
        sessionId,
        reason,
      });
    }

    const sessionId = this.deps.crypto.newId();
    const accessToken = this.deps.crypto.generateOpaqueToken();
    const refreshToken = this.deps.crypto.generateOpaqueToken();
    const accessTokenExpiresAt = new Date(params.now.getTime() + ACCESS_TOKEN_TTL_MS);

    await this.deps.repository.insertSession(tx, {
      sessionId,
      familyId: params.familyId,
      memberId: params.memberId,
      refreshTokenHash: this.deps.crypto.hashToken(refreshToken),
      installationProofHash: params.installationProofHash,
    });

    await this.deps.repository.insertAccessToken(tx, {
      accessTokenId: this.deps.crypto.newId(),
      sessionId,
      tokenHash: this.deps.crypto.hashToken(accessToken),
      expiresAt: accessTokenExpiresAt,
    });

    return {
      sessionId,
      memberId: params.memberId,
      familyId: params.familyId,
      role: params.role,
      isFamilyCreator: params.isFamilyCreator,
      accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
      refreshToken,
    };
  }
}
