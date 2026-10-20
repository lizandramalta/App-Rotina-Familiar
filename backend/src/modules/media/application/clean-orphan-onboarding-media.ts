import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { ObjectStorageMaintenancePort } from './media-ports.js';
import type { OnboardingMediaPort } from './onboarding-media-port.js';

const RETENTION_MS = 24 * 60 * 60 * 1000;

/** Claims expired reservations under a row lock; retries deletion after a failure. */
export class CleanOrphanOnboardingMedia {
  constructor(
    private readonly deps: {
      repository: OnboardingMediaPort;
      storage: ObjectStorageMaintenancePort;
      transactionRunner: TransactionRunner;
      clock: Clock;
      logger: Logger;
    },
  ) {}

  public async run(): Promise<void> {
    const before = new Date(this.deps.clock.now().getTime() - RETENTION_MS);
    const claimed = await this.deps.transactionRunner.run((tx) =>
      this.deps.repository.claimExpired(tx, before, 50),
    );
    for (const media of claimed) {
      try {
        await this.deps.storage.delete(media.objectKey);
        await this.deps.transactionRunner.run((tx) =>
          this.deps.repository.deleteClaimed(tx, media.id),
        );
      } catch (error) {
        this.deps.logger.error('onboarding_media_cleanup_failed', error, { mediaId: media.id });
      }
    }
  }
}
