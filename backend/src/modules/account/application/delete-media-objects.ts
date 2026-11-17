import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { ObjectStorageMaintenancePort } from '../../media/application/media-ports.js';
import type { MediaObjectDeletionQueuePort } from './account-deletion-ports.js';
import { QUEUE_LEASE_MS, nextRetryDelayMs, sanitizedReason } from './post-commit-queue-policy.js';

const BATCH_SIZE = 50;

/**
 * Apaga no R2 os objetos de contas e famílias excluídas (SPEC-022 CA-04/CA-12,
 * RNF24, RNF28). Executado pelo worker, fora de qualquer transação de exclusão.
 */
export class DeleteMediaObjects {
  constructor(
    private readonly deps: {
      readonly queue: MediaObjectDeletionQueuePort;
      readonly storage: ObjectStorageMaintenancePort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
      readonly newId: () => string;
      readonly maxAttempts: number;
    },
  ) {}

  public async run(): Promise<void> {
    const now = this.deps.clock.now();
    const claimId = this.deps.newId();
    const claimed = await this.deps.transactionRunner.run((tx) =>
      this.deps.queue.claimDue(tx, {
        now,
        claimId,
        leaseUntil: new Date(now.getTime() + QUEUE_LEASE_MS),
        limit: BATCH_SIZE,
      }),
    );

    for (const item of claimed) {
      const attempts = item.attempts + 1;
      try {
        await this.deps.storage.delete(item.objectKey);
        await this.deps.transactionRunner.run((tx) =>
          this.deps.queue.complete(tx, {
            id: item.id,
            claimId,
            objectKey: item.objectKey,
            outcome: 'DELETED',
          }),
        );
      } catch (error) {
        const reason = sanitizedReason(error);
        if (attempts >= this.deps.maxAttempts) {
          await this.deps.transactionRunner.run((tx) =>
            this.deps.queue.complete(tx, {
              id: item.id,
              claimId,
              objectKey: item.objectKey,
              outcome: 'FAILED',
            }),
          );
          this.deps.logger.error('media_deletion_failed', undefined, {
            attempt: attempts,
            reason,
            exhausted: true,
          });
          continue;
        }
        await this.deps.transactionRunner.run((tx) =>
          this.deps.queue.reschedule(tx, {
            id: item.id,
            claimId,
            attempts,
            nextAttemptAt: new Date(this.deps.clock.now().getTime() + nextRetryDelayMs(attempts)),
            lastError: reason,
          }),
        );
        this.deps.logger.warn('media_deletion_failed', {
          attempt: attempts,
          reason,
          exhausted: false,
        });
      }
    }
  }
}
