import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import { CreationGrantInvalidError } from '../../family/domain/family-errors.js';
import type { ImageProcessorPort, ObjectStoragePort } from './media-ports.js';
import type { OnboardingMediaPort } from './onboarding-media-port.js';

export interface UploadOnboardingMediaCommand {
  readonly creationGrant: unknown;
  readonly installationProof: string;
  readonly purpose: unknown;
  readonly content: Buffer;
}

export class UploadOnboardingMediaUseCase {
  constructor(
    private readonly deps: {
      repository: OnboardingMediaPort;
      storage: ObjectStoragePort;
      imageProcessor: ImageProcessorPort;
      crypto: Pick<AccessCryptoPort, 'newId' | 'hashToken'>;
      transactionRunner: TransactionRunner;
      clock: Clock;
      logger: Logger;
      keyPrefix: string;
    },
  ) {}

  public async execute(
    command: UploadOnboardingMediaCommand,
  ): Promise<{ mediaId: string; state: 'READY'; width: number; height: number }> {
    if (command.purpose !== 'profilePhoto') {
      throw new ValidationError('The media purpose is not supported.', {
        purpose: ['MEDIA_PURPOSE_INVALID'],
      });
    }
    if (typeof command.creationGrant !== 'string' || command.creationGrant.length === 0) {
      throw new CreationGrantInvalidError();
    }
    const { repository, crypto, transactionRunner } = this.deps;
    const id = crypto.newId();
    const objectKey = `${this.deps.keyPrefix}/onboarding/profile-photos/${id}.jpg`;

    try {
      await transactionRunner.run(async (tx) => {
        const grantId = await repository.findUsableGrant(
          tx,
          crypto.hashToken(command.creationGrant as string),
          crypto.hashToken(command.installationProof),
          this.deps.clock.now(),
        );
        if (grantId === undefined) throw new CreationGrantInvalidError();
        await repository.reserve(tx, { id, grantId, objectKey });
      });
    } catch (error) {
      if (error instanceof DomainError) throw error;
      this.deps.logger.error('onboarding_media_reservation_failed', error);
      throw new DependencyUnavailableError();
    }

    let image;
    try {
      image = await this.deps.imageProcessor.processProfilePhoto(command.content);
      await this.deps.storage.put({
        key: objectKey,
        body: image.body,
        contentType: image.contentType,
      });
    } catch (error) {
      await this.markFailedQuietly(id);
      if (error instanceof DomainError) throw error;
      this.deps.logger.error('onboarding_media_upload_failed', error, { mediaId: id });
      throw new DependencyUnavailableError();
    }

    try {
      await transactionRunner.run((tx) =>
        repository.markReady(tx, {
          id,
          sizeBytes: image.sizeBytes,
          contentType: image.contentType,
        }),
      );
    } catch (error) {
      this.deps.logger.error('onboarding_media_ready_failed', error, { mediaId: id });
      throw new DependencyUnavailableError();
    }
    return { mediaId: id, state: 'READY', width: image.width, height: image.height };
  }

  private async markFailedQuietly(id: string): Promise<void> {
    try {
      await this.deps.transactionRunner.run((tx) => this.deps.repository.markFailed(tx, id));
    } catch (error) {
      this.deps.logger.error('onboarding_media_failed_transition_failed', error, { mediaId: id });
    }
  }
}
