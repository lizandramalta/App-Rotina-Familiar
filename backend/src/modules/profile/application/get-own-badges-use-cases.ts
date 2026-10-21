import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { NotFoundError } from '../../../shared/domain/domain-error.js';
import type { BadgeAwardRecord, ProfileRepositoryPort } from './profile-repository-port.js';
import { toNextTierResponse, type NextTierResponse } from './own-profile-response.js';

export interface OwnBadgeAwardView {
  readonly awardId: string;
  readonly tier: string;
  readonly requiredMissionCount: number;
  readonly awardedAt: string;
}

export interface OwnBadgesResponse {
  readonly totalParticipations: number;
  readonly nextTier: NextTierResponse | null;
  readonly awards: readonly OwnBadgeAwardView[];
}

export interface BadgeContributionMissionView {
  readonly missionId: string;
  readonly title: string;
  readonly completedAt: string | null;
}

export interface BadgeContributionsResponse {
  readonly awardId: string;
  readonly tier: string;
  readonly awardedAt: string;
  readonly contributingMissions: readonly BadgeContributionMissionView[];
}

function toAwardView(award: BadgeAwardRecord): OwnBadgeAwardView {
  return {
    awardId: award.awardId,
    tier: award.tier,
    requiredMissionCount: award.requiredMissionCount,
    awardedAt: award.awardedAt.toISOString(),
  };
}

/** `GetOwnBadges` (SPEC-006 Fase 1, CA-10/CA-12): marcos cumulativos do titular. */
export class GetOwnBadgesUseCase {
  constructor(
    private readonly deps: {
      readonly profileRepository: ProfileRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext): Promise<OwnBadgesResponse> {
    return this.deps.transactionRunner.run(async (tx) => {
      const familyId = actor.familyId;
      const memberId = actor.memberId;

      const [progress, awards] = await Promise.all([
        this.deps.profileRepository.findBadgeProgress(tx, { familyId, memberId }),
        this.deps.profileRepository.findBadgeAwards(tx, { familyId, memberId }),
      ]);

      return {
        totalParticipations: progress.totalParticipations,
        nextTier: toNextTierResponse(progress),
        awards: awards.map(toAwardView),
      };
    });
  }
}

/**
 * `GetBadgeContributions` (SPEC-006 Fase 1, CA-05/CA-11): marco de outro
 * membro — da mesma família ou de outra — responde `404`, sem distinguir os
 * casos (RNF06).
 */
export class GetBadgeContributionsUseCase {
  constructor(
    private readonly deps: {
      readonly profileRepository: ProfileRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext, awardId: string): Promise<BadgeContributionsResponse> {
    return this.deps.transactionRunner.run(async (tx) => {
      const familyId = actor.familyId;
      const memberId = actor.memberId;

      const award = await this.deps.profileRepository.findBadgeAward(tx, {
        familyId,
        memberId,
        awardId,
      });
      if (award === undefined) {
        throw new NotFoundError('Badge award not found.');
      }

      const missions = await this.deps.profileRepository.findContributingMissions(tx, {
        familyId,
        memberId,
        awardId,
      });

      return {
        awardId: award.awardId,
        tier: award.tier,
        awardedAt: award.awardedAt.toISOString(),
        contributingMissions: missions.map((mission) => ({
          missionId: mission.missionId,
          title: mission.title,
          completedAt: mission.completedAt?.toISOString() ?? null,
        })),
      };
    });
  }
}
