import type { ActorContext } from '../../../shared/application/actor-context.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import {
  MediaPurpose,
  type ImageProcessorPort,
  type MediaRepositoryPort,
  type ObjectStoragePort,
} from './media-ports.js';

export interface UploadMediaCommand {
  readonly actor: ActorContext;
  /** Raw purpose: profile photo or an optional Kids task signal photo. */
  readonly purpose: unknown;
  readonly content: Buffer;
}

export interface UploadMediaResult {
  readonly mediaId: string;
  readonly state: 'READY';
  readonly width: number;
  readonly height: number;
}

/**
 * `UploadMedia` para a foto de perfil (SPEC-002 §5.2). Segue
 * backend-architecture.md §13: reserva o registro antes do I/O, grava o objeto
 * e só então marca a mídia como pronta. Banco e R2 não compartilham transação,
 * por isso cada etapa tem a sua.
 */
export class UploadMediaUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MediaRepositoryPort;
      readonly storage: ObjectStoragePort;
      readonly imageProcessor: ImageProcessorPort;
      readonly crypto: Pick<AccessCryptoPort, 'newId'>;
      readonly transactionRunner: TransactionRunner;
      readonly logger: Logger;
      /** Prefixo de ambiente da chave: desenvolvimento e produção não se misturam. */
      readonly keyPrefix: string;
    },
  ) {}

  public async execute(command: UploadMediaCommand): Promise<UploadMediaResult> {
    if (command.purpose !== 'profilePhoto' && command.purpose !== 'taskSignal') {
      throw new ValidationError('The media purpose is not supported.', {
        purpose: ['MEDIA_PURPOSE_INVALID'],
      });
    }
    if (command.purpose === 'taskSignal' && command.actor.role !== MemberRole.KIDS) {
      throw new DomainError({
        message: 'Only Kids can upload task signal photos.',
        code: 'ACTION_NOT_ALLOWED',
        statusCode: 403,
      });
    }

    const image = await this.deps.imageProcessor.processProfilePhoto(command.content);

    const { actor } = command;
    const mediaId = this.deps.crypto.newId();
    const objectKey = `${this.deps.keyPrefix}/families/${actor.familyId}/${command.purpose === 'taskSignal' ? 'task-signals' : 'profile-photos'}/${mediaId}.jpg`;

    try {
      await this.deps.transactionRunner.run((tx) =>
        this.deps.repository.reserve(tx, {
          mediaId,
          familyId: actor.familyId,
          ownerMemberId: actor.memberId,
          objectKey,
          purpose:
            command.purpose === 'taskSignal'
              ? MediaPurpose.TASK_SIGNAL
              : MediaPurpose.PROFILE_PHOTO,
        }),
      );
    } catch (error) {
      this.deps.logger.error('media_reservation_failed', error);
      throw new DependencyUnavailableError();
    }

    try {
      await this.deps.storage.put({
        key: objectKey,
        body: image.body,
        contentType: image.contentType,
      });
    } catch (error) {
      if (!(error instanceof DomainError)) {
        this.deps.logger.error('media_object_write_failed', error, { mediaId });
      }
      await this.markFailedQuietly(mediaId);
      throw new DependencyUnavailableError();
    }

    try {
      await this.deps.transactionRunner.run((tx) =>
        this.deps.repository.markReady(tx, {
          mediaId,
          sizeBytes: image.sizeBytes,
          contentType: image.contentType,
        }),
      );
    } catch (error) {
      // O objeto existe, mas a mídia segue `UPLOADING`: o worker de limpeza
      // reconcilia (§13). A resposta não afirma que ficou pronta.
      this.deps.logger.error('media_ready_transition_failed', error, { mediaId });
      throw new DependencyUnavailableError();
    }

    return { mediaId, state: 'READY', width: image.width, height: image.height };
  }

  private async markFailedQuietly(mediaId: string): Promise<void> {
    try {
      await this.deps.transactionRunner.run((tx) => this.deps.repository.markFailed(tx, mediaId));
    } catch (error) {
      this.deps.logger.error('media_failed_transition_failed', error, { mediaId });
    }
  }
}
