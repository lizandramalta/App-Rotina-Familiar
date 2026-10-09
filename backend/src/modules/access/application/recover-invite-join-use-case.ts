import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { DependencyUnavailableError, DomainError } from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import { JoinRecoveryUnavailableError, RateLimitedError } from '../domain/invite-errors.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { InviteAttemptPolicy } from './invite-attempt-policy.js';
import type { InviteAttemptLimiterPort } from './invite-attempt-limiter-port.js';
import type { InviteJoinEnvelopePort } from './invite-join-envelope-port.js';
import type { RecoverInviteJoinCommand } from './invite-join-dto.js';
import type { InviteJoinRepositoryPort } from './invite-join-repository-port.js';
import type { IssuedSession } from './session-issuer.js';

const ROUTE = 'POST /v1/access/invite-joins/recover';

type RecoveryOutcome =
  | { readonly kind: 'recovered'; readonly session: IssuedSession }
  | { readonly kind: 'unavailable' };

/**
 * `RecoverInviteJoin` (UC09, SPEC-005 CA-07/CA-08).
 *
 * Devolve as credenciais do ingresso já confirmado, sem senha e sem consumir o
 * convite outra vez. Exige as provas originais, a janela de dez minutos e a
 * sessão ainda ativa; qualquer outro caso é a mesma resposta neutra.
 */
export class RecoverInviteJoinUseCase {
  constructor(
    private readonly deps: {
      readonly repository: InviteJoinRepositoryPort;
      readonly envelope: InviteJoinEnvelopePort;
      readonly limiter: InviteAttemptLimiterPort;
      readonly crypto: Pick<AccessCryptoPort, 'hashToken' | 'hashesMatch'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
      readonly policy: InviteAttemptPolicy;
    },
  ) {}

  public async execute(command: RecoverInviteJoinCommand): Promise<IssuedSession> {
    try {
      const now = this.deps.clock.now();
      const { policy } = this.deps;

      const exceeded = await this.deps.limiter.recordAndCheckExceeded({
        scope: 'origin',
        subjectHash: this.deps.crypto.hashToken(`origin:${command.origin}`),
        limit: policy.originLimit,
        now,
        windowMs: policy.windowMs,
      });
      if (exceeded) {
        throw new RateLimitedError(Math.ceil(policy.windowMs / 1000));
      }

      const attemptSecretHash = this.deps.crypto.hashToken(command.attemptSecret);
      const installationProofHash = this.deps.crypto.hashToken(command.installationProof);

      // A remoção do envelope expirado precisa ser confirmada, então o desfecho
      // sai da transação como valor: lançar dentro dela faria rollback do DELETE.
      const outcome = await this.deps.transactionRunner.run<RecoveryOutcome>(async (tx) => {
        const recovery = await this.deps.repository.findJoinRecovery(tx, command.attemptId);
        if (recovery === undefined) {
          return { kind: 'unavailable' };
        }

        if (recovery.expiresAt.getTime() <= now.getTime()) {
          await this.deps.repository.deleteJoinRecovery(tx, recovery.attemptId);
          return { kind: 'unavailable' };
        }

        // Os dois hashes são comparados sempre, sem curto-circuito, para que o
        // tempo não diga qual das provas acertou.
        const secretMatches = this.deps.crypto.hashesMatch(
          recovery.attemptSecretHash,
          attemptSecretHash,
        );
        const proofMatches = this.deps.crypto.hashesMatch(
          recovery.installationProofHash,
          installationProofHash,
        );
        if (!secretMatches || !proofMatches || !recovery.sessionActive) {
          return { kind: 'unavailable' };
        }

        try {
          return {
            kind: 'recovered',
            session: this.deps.envelope.open(recovery.attemptId, recovery.envelope),
          };
        } catch {
          return { kind: 'unavailable' };
        }
      });

      if (outcome.kind === 'unavailable') {
        throw new JoinRecoveryUnavailableError();
      }

      this.deps.logger.info('invite_join_recovery', {
        requestId: command.requestId,
        result: 'recovered',
        sessionId: outcome.session.sessionId,
        at: now.toISOString(),
      });

      return outcome.session;
    } catch (error) {
      if (error instanceof DomainError) {
        this.deps.logger.warn('invite_join_recovery', {
          requestId: command.requestId,
          route: ROUTE,
          result: 'denied',
          code: error.code,
        });
        throw error;
      }

      this.deps.logger.error('invite_join_recovery_failed', undefined, {
        requestId: command.requestId,
        route: ROUTE,
        failure: error instanceof Error ? error.name : 'UnknownFailure',
      });
      throw new DependencyUnavailableError();
    }
  }
}
