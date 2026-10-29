import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { DependencyUnavailableError, DomainError } from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import { InviteUnavailableError, RateLimitedError } from '../domain/invite-errors.js';
import type { AccessCryptoPort } from './access-crypto-port.js';
import type { InviteAttemptLimiterPort } from './invite-attempt-limiter-port.js';
import type { InviteAttemptPolicy } from './invite-attempt-policy.js';
import type { InspectInviteCommand, InspectInviteResult } from './invite-join-dto.js';
import type { InviteJoinRepositoryPort } from './invite-join-repository-port.js';

const ROUTE = 'POST /v1/access/invites/inspect';

/**
 * `InspectInvite` (UC09, SPEC-005 CA-01/CA-04).
 *
 * Devolve apenas se o convite está disponível: nome, foto, família, papel e
 * senha nunca saem daqui (RNF18–RNF20). Qualquer indisponibilidade — token
 * desconhecido, consumido ou invalidado — é a mesma resposta neutra.
 */
export class InspectInviteUseCase {
  constructor(
    private readonly deps: {
      readonly repository: InviteJoinRepositoryPort;
      readonly limiter: InviteAttemptLimiterPort;
      readonly crypto: Pick<AccessCryptoPort, 'hashToken'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
      readonly policy: InviteAttemptPolicy;
    },
  ) {}

  public async execute(command: InspectInviteCommand): Promise<InspectInviteResult> {
    const { requestId } = command;

    try {
      const now = this.deps.clock.now();
      const { policy } = this.deps;

      // Posse do token também é limitada: sem isto a inspeção serviria para
      // varrer tokens sem custo (SPEC-005 §5.1).
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

      const invite = await this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findInviteByTokenHash(tx, this.deps.crypto.hashToken(command.token)),
      );

      if (invite === undefined || invite.status !== 'available') {
        throw new InviteUnavailableError();
      }

      return { status: 'available' };
    } catch (error) {
      if (error instanceof DomainError) {
        // Somente a classificação neutra: nada do token entra no log.
        this.deps.logger.warn('invite_inspection_denied', {
          requestId,
          route: ROUTE,
          code: error.code,
        });
        throw error;
      }
      this.deps.logger.error('invite_inspection_failed', undefined, {
        requestId,
        route: ROUTE,
        failure: error instanceof Error ? error.name : 'UnknownFailure',
      });
      throw new DependencyUnavailableError();
    }
  }
}
