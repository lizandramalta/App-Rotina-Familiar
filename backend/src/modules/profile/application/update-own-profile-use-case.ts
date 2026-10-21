import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { NotFoundError, ValidationError } from '../../../shared/domain/domain-error.js';
import { normalizeNickname } from '../../family/domain/text-rules.js';
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
import { toOwnProfileResponse, type OwnProfileResponse } from './own-profile-response.js';

export interface UpdateOwnProfileCommand {
  readonly actor: ActorContext;
  /** Omitido preserva o apelido vigente; `null`/vazio remove a configuração (RN63). */
  readonly nickname?: string | null;
  /** Omitido preserva a foto vigente; `null` remove a foto. */
  readonly photoMediaId?: string | null;
}

function validateNickname(input: string | null): string | null {
  const normalized = normalizeNickname(input);
  if ('value' in normalized) {
    return normalized.value;
  }
  // SPEC-006 define só NICKNAME_INVALID_LENGTH para o campo; conteúdo de
  // controle (caso raro) reaproveita o mesmo código, já que a SPEC não
  // distingue um segundo código para essa situação.
  throw new ValidationError('The nickname is invalid.', {
    nickname: ['NICKNAME_INVALID_LENGTH'],
  });
}

/**
 * `UpdateOwnProfile` (SPEC-006 Fase 1, CA-02/06/07/09): `nickname` e
 * `photoMediaId` são independentes e opcionais — omitir um campo preserva seu
 * valor vigente. Nenhum dos dois altera papel, família ou modo Kids.
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

  public async execute(command: UpdateOwnProfileCommand): Promise<OwnProfileResponse> {
    const { actor } = command;

    // Lock da família: a mídia é revalidada dentro dele, não antes (BA-08).
    return this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
      const now = this.deps.clock.now();

      const current = await this.deps.profileRepository.findOwnProfile(tx, {
        familyId: actor.familyId,
        memberId: actor.memberId,
      });
      if (current === undefined) {
        throw new NotFoundError('Member not found.');
      }

      let nickname = current.nickname;
      if (command.nickname !== undefined) {
        nickname = validateNickname(command.nickname);
        await this.deps.profileRepository.setNickname(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
          nickname,
          updatedAt: now,
        });
      }

      let photoMediaId = current.photoMediaId;
      if (command.photoMediaId !== undefined) {
        photoMediaId = command.photoMediaId;

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
      }

      const progress = await this.deps.profileRepository.findBadgeProgress(tx, {
        familyId: actor.familyId,
        memberId: actor.memberId,
      });

      return toOwnProfileResponse({
        memberId: actor.memberId,
        name: current.name,
        nickname,
        photoMediaId,
        progress,
      });
    });
  }
}
