/** Casos de uso `GetOwnBadges`/`GetBadgeContributions` (SPEC-006 Fase 1): CA-05, CA-10, CA-11, CA-12. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  GetBadgeContributionsUseCase,
  GetOwnBadgesUseCase,
} from '../../src/modules/profile/application/get-own-badges-use-cases.js';
import type {
  BadgeAwardRecord,
  ProfileRepositoryPort,
} from '../../src/modules/profile/application/profile-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const AWARDED_AT = new Date('2026-09-20T12:00:00.000Z');
const SILVER_AWARD: BadgeAwardRecord = {
  awardId: 'e5f6a7b8-0000-0000-0000-000000000001',
  tier: 'silver',
  requiredMissionCount: 10,
  awardedAt: AWARDED_AT,
};

describe('GetOwnBadgesUseCase — SPEC-006', () => {
  let profileRepository: {
    findBadgeProgress: ReturnType<typeof vi.fn>;
    findBadgeAwards: ReturnType<typeof vi.fn>;
  };
  let transactionRunner: TransactionRunner;
  let useCase: GetOwnBadgesUseCase;

  beforeEach(() => {
    profileRepository = {
      findBadgeProgress: vi.fn().mockResolvedValue({
        totalParticipations: 10,
        nextTier: { code: 'gold', requiredMissionCount: 25 },
      }),
      findBadgeAwards: vi.fn().mockResolvedValue([SILVER_AWARD]),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(),
    } as unknown as TransactionRunner;

    useCase = new GetOwnBadgesUseCase({
      profileRepository: profileRepository as unknown as ProfileRepositoryPort,
      transactionRunner,
    });
  });

  it('CA-11 lists cumulative awards with progress and next tier', async () => {
    const result = await useCase.execute(TEST_ACTOR);

    expect(profileRepository.findBadgeAwards).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
    });
    expect(result).toEqual({
      totalParticipations: 10,
      nextTier: { code: 'gold', requiredMissionCount: 25, remaining: 15 },
      awards: [
        {
          awardId: SILVER_AWARD.awardId,
          tier: 'silver',
          requiredMissionCount: 10,
          awardedAt: AWARDED_AT.toISOString(),
        },
      ],
    });
  });

  it('CA-10 returns an empty award list and nextTier bronze(5) with no participations', async () => {
    profileRepository.findBadgeProgress.mockResolvedValue({
      totalParticipations: 0,
      nextTier: { code: 'bronze', requiredMissionCount: 5 },
    });
    profileRepository.findBadgeAwards.mockResolvedValue([]);

    const result = await useCase.execute(TEST_ACTOR);

    expect(result.awards).toEqual([]);
    expect(result.totalParticipations).toBe(0);
    expect(result.nextTier).toEqual({ code: 'bronze', requiredMissionCount: 5, remaining: 5 });
  });

  it('CA-12 allows a Kids session on the same terms as an adult', async () => {
    const result = await useCase.execute({ ...TEST_ACTOR, role: MemberRole.KIDS });

    expect(result.awards).toHaveLength(1);
  });
});

describe('GetBadgeContributionsUseCase — SPEC-006', () => {
  let profileRepository: {
    findBadgeAward: ReturnType<typeof vi.fn>;
    findContributingMissions: ReturnType<typeof vi.fn>;
  };
  let transactionRunner: TransactionRunner;
  let useCase: GetBadgeContributionsUseCase;

  beforeEach(() => {
    profileRepository = {
      findBadgeAward: vi.fn().mockResolvedValue(SILVER_AWARD),
      findContributingMissions: vi.fn().mockResolvedValue([
        {
          missionId: 'f6a7b8c9-0000-0000-0000-000000000001',
          title: 'Organizar a sala',
          completedAt: new Date('2026-09-18T20:00:00.000Z'),
        },
      ]),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(),
    } as unknown as TransactionRunner;

    useCase = new GetBadgeContributionsUseCase({
      profileRepository: profileRepository as unknown as ProfileRepositoryPort,
      transactionRunner,
    });
  });

  it('CA-11 returns the award detail with missionId and title of each contributing mission', async () => {
    const result = await useCase.execute(TEST_ACTOR, SILVER_AWARD.awardId);

    expect(profileRepository.findBadgeAward).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
      awardId: SILVER_AWARD.awardId,
    });
    expect(result).toEqual({
      awardId: SILVER_AWARD.awardId,
      tier: 'silver',
      awardedAt: AWARDED_AT.toISOString(),
      contributingMissions: [
        {
          missionId: 'f6a7b8c9-0000-0000-0000-000000000001',
          title: 'Organizar a sala',
          completedAt: '2026-09-18T20:00:00.000Z',
        },
      ],
    });
  });

  it('CA-05 answers 404 for an award that belongs to another member, without revealing metadata', async () => {
    profileRepository.findBadgeAward.mockResolvedValue(undefined);

    const error = await useCase.execute(TEST_ACTOR, SILVER_AWARD.awardId).catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
    expect(profileRepository.findContributingMissions).not.toHaveBeenCalled();
  });

  it('CA-12 allows a Kids session on the same terms as an adult', async () => {
    const result = await useCase.execute(
      { ...TEST_ACTOR, role: MemberRole.KIDS },
      SILVER_AWARD.awardId,
    );

    expect(result.awardId).toBe(SILVER_AWARD.awardId);
  });
});
