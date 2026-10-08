import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { NotFoundError } from '../../../shared/domain/domain-error.js';
import {
  PhotoMediaNotOwnedError,
  PhotoMediaNotReadyError,
  PhotoMediaPurposeMismatchError,
} from '../../media/domain/media-errors.js';
import {
  MediaPurpose,
  MediaState,
  type MediaRepositoryPort,
} from '../../media/application/media-ports.js';
import type { ProfileRepositoryPort } from './profile-repository-port.js';

export interface UpdateOwnProfileCommand {
  readonly actor: ActorContext;
  /** `null` remove a foto. */
  readonly photoMediaId: string | null;
}

export interface UpdateOwnProfileResult {
  readonly photoMediaId: string | null;
}

/**
 * `UpdateOwnProfile`, no recorte da SPEC-002: vincula (ou remove) a foto do
 * próprio titular. Apelido e demais campos pertencem à SPEC-006.
 */
export class UpdateOwnProfileUseCase {
  constructor(
    private readonly deps: {
      readonly profileRepository: ProfileRepositoryPort;
      readonly mediaRepository: MediaRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: UpdateOwnProfileCommand): Promise<UpdateOwnProfileResult> {
    const { actor, photoMediaId } = command;

    // Lock da família: a mídia é revalidada dentro dele, não antes (BA-08).
    return this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
      const now = this.deps.clock.now();

      if (photoMediaId !== null) {
        const media = await this.deps.mediaRepository.findInFamily(tx, {
          familyId: actor.familyId,
          mediaId: photoMediaId,
        });

        // Outra família e mídia inexistente respondem igual (404), sem revelar
        // que o identificador existe.
        if (media === undefined) {
          throw new NotFoundError('Media not found.');
        }

        if (media.ownerMemberId !== actor.memberId) {
          throw new PhotoMediaNotOwnedError();
        }

        if (media.purpose !== MediaPurpose.PROFILE_PHOTO) {
          throw new PhotoMediaPurposeMismatchError();
        }

        if (media.state !== MediaState.READY) {
          throw new PhotoMediaNotReadyError();
        }

        await this.deps.mediaRepository.markLinked(tx, { mediaId: media.id, linkedAt: now });
      }

      await this.deps.profileRepository.setPhoto(tx, {
        familyId: actor.familyId,
        memberId: actor.memberId,
        photoMediaId,
        updatedAt: now,
      });

      return { photoMediaId };
    });
  }
}
