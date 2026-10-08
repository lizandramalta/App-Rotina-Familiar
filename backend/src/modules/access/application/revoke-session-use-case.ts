import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { AccessRepositoryPort } from './access-repository-port.js';
import { assertSessionIsActive } from './active-session.js';
import type { AccessTokenCommand } from './session-dto.js';

/** Motivo registrado na revogação pedida pelo próprio titular (CA-09). */
const EXPLICIT_SIGN_OUT_REASON = 'explicit_sign_out';

/**
 * `RevokeSession` (CA-09, SPEC-001 §5.2.4).
 *
 * Encerra a sessão e os access tokens dela no mesmo commit, para que o token
 * recém-usado não continue valendo depois da resposta (CA-05). O membro não é
 * removido de `app.members`: a pessoa continua na família.
 */
export class RevokeSessionUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccessRepositoryPort;
      readonly crypto: AccessCryptoPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: AccessTokenCommand): Promise<void> {
    const tokenHash = this.deps.crypto.hashToken(command.accessToken);
    const now = this.deps.clock.now();

    const revokedSessionId = await this.deps.transactionRunner.run(async (tx) => {
      const record = await this.deps.repository.findSessionAndMemberByAccessTokenHash(
        tx,
        tokenHash,
      );
      const session = assertSessionIsActive(record, now);

      const revoked = await this.deps.repository.revokeSessionById(tx, {
        sessionId: session.sessionId,
        reason: EXPLICIT_SIGN_OUT_REASON,
      });

      await this.deps.repository.revokeAccessTokensForSession(tx, session.sessionId);

      return revoked ? session.sessionId : undefined;
    });

    // Só registra se esta chamada foi a que encerrou a sessão: um segundo
    // DELETE não deve duplicar o evento de segurança.
    if (revokedSessionId !== undefined) {
      this.deps.logger.info('session_revoked', {
        sessionId: revokedSessionId,
        reason: EXPLICIT_SIGN_OUT_REASON,
      });
    }
  }
}
