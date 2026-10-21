import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { NotFoundError } from '../../../shared/domain/domain-error.js';
import type { ProfileRepositoryPort } from './profile-repository-port.js';
import { toOwnProfileResponse, type OwnProfileResponse } from './own-profile-response.js';

/**
 * `GetOwnProfile` (SPEC-006 Fase 1, CA-01): qualquer papel, inclusive Kids,
 * consulta exclusivamente o próprio perfil — a rota não aceita `memberId`.
 */
export class GetOwnProfileUseCase {
  constructor(
    private readonly deps: {
      readonly profileRepository: ProfileRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext): Promise<OwnProfileResponse> {
    return this.deps.transactionRunner.run(async (tx) => {
      const profile = await this.deps.profileRepository.findOwnProfile(tx, {
        familyId: actor.familyId,
        memberId: actor.memberId,
      });
      if (profile === undefined) {
        throw new NotFoundError('Member not found.');
      }

      const progress = await this.deps.profileRepository.findBadgeProgress(tx, {
        familyId: actor.familyId,
        memberId: actor.memberId,
      });

      return toOwnProfileResponse({
        memberId: actor.memberId,
        name: profile.name,
        nickname: profile.nickname,
        photoMediaId: profile.photoMediaId,
        progress,
      });
    });
  }
}
