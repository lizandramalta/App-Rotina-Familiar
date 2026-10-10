import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { SessionRevokedError } from '../domain/access-errors.js';
import { ACCESS_TOKEN_TTL_MS } from './access-token-ttl.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort } from './access-repository-port.js';
import type { RefreshSessionCommand, RefreshedAccessResult } from './session-dto.js';

/**
 * `RefreshSession` (CA-08, SPEC-001 §5.2.3).
 *
 * Emite um novo access token de 15 minutos sem tocar nos anteriores: os que
 * ainda estão dentro da janela continuam válidos (BA-10). O refresh token é
 * estável e não é reemitido.
 */
export class RefreshSessionUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccessRepositoryPort;
      readonly crypto: AccessCryptoPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: RefreshSessionCommand): Promise<RefreshedAccessResult> {
    const refreshTokenHash = this.deps.crypto.hashToken(command.refreshToken);
    const installationProofHash = this.deps.crypto.hashToken(command.installationProof);
    const now = this.deps.clock.now();

    const accessToken = this.deps.crypto.generateOpaqueToken();
    const accessTokenExpiresAt = new Date(now.getTime() + ACCESS_TOKEN_TTL_MS);

    // Emissão e marcação de atividade correm no mesmo commit: um token entregue
    // ao cliente e não persistido deixaria a sessão em estado que ela não tem.
    await this.deps.transactionRunner.run(async (tx) => {
      const session = await this.deps.repository.findSessionByRefreshTokenHash(
        tx,
        refreshTokenHash,
      );

      // Sessão inexistente, encerrada ou de outra instalação recebem a mesma
      // resposta: distingui-las diria ao chamador qual metade da credencial
      // acertou (CA-08, RNF08).
      if (
        session === undefined ||
        session.revokedAt !== undefined ||
        !this.deps.crypto.hashesMatch(session.installationProofHash, installationProofHash)
      ) {
        throw new SessionRevokedError();
      }

      await this.deps.repository.insertAccessToken(tx, {
        accessTokenId: this.deps.crypto.newId(),
        sessionId: session.sessionId,
        tokenHash: this.deps.crypto.hashToken(accessToken),
        expiresAt: accessTokenExpiresAt,
      });

      await this.deps.repository.touchSessionLastSeen(tx, session.sessionId);
    });

    return {
      accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
    };
  }
}
