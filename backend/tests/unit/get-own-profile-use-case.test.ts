/** Caso de uso `GetOwnProfile` (SPEC-006 Fase 1): CA-01, CA-10, CA-12. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { GetOwnProfileUseCase } from '../../src/modules/profile/application/get-own-profile-use-case.js';
import type {
  OwnProfileRecord,
  ProfileRepositoryPort,
} from '../../src/modules/profile/application/profile-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const PROFILE: OwnProfileRecord = {
  name: 'Maria Silva',
  nickname: 'Mari',
  photoMediaId: 'media-1',
};

describe('GetOwnProfileUseCase — SPEC-006', () => {
  let profileRepository: {
    findOwnProfile: ReturnType<typeof vi.fn>;
    findBadgeProgress: ReturnType<typeof vi.fn>;
  };
  let transactionRunner: TransactionRunner;
  let useCase: GetOwnProfileUseCase;

  beforeEach(() => {
    profileRepository = {
      findOwnProfile: vi.fn().mockResolvedValue(PROFILE),
      findBadgeProgress: vi.fn().mockResolvedValue({
        totalParticipations: 7,
        nextTier: { code: 'silver', requiredMissionCount: 10 },
      }),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(),
    } as unknown as TransactionRunner;

    useCase = new GetOwnProfileUseCase({
      profileRepository: profileRepository as unknown as ProfileRepositoryPort,
      transactionRunner,
    });
  });

  it('CA-01 returns name, nickname, photo, total participations and next tier', async () => {
    const result = await useCase.execute(TEST_ACTOR);

    expect(profileRepository.findOwnProfile).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
    });
    expect(result).toEqual({
      memberId: TEST_ACTOR.memberId,
      name: 'Maria Silva',
      nickname: 'Mari',
      photoMediaId: 'media-1',
      totalParticipations: 7,
      nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 3 },
    });
  });

  it('CA-10 returns totalParticipations: 0 and nextTier bronze(5) with no participations', async () => {
    profileRepository.findBadgeProgress.mockResolvedValue({
      totalParticipations: 0,
      nextTier: { code: 'bronze', requiredMissionCount: 5 },
    });

    const result = await useCase.execute(TEST_ACTOR);

    expect(result.totalParticipations).toBe(0);
    expect(result.nextTier).toEqual({ code: 'bronze', requiredMissionCount: 5, remaining: 5 });
  });

  it('returns nextTier: null once the titular already reached diamond', async () => {
    profileRepository.findBadgeProgress.mockResolvedValue({
      totalParticipations: 50,
      nextTier: null,
    });

    const result = await useCase.execute(TEST_ACTOR);

    expect(result.nextTier).toBeNull();
  });

  it('CA-12 allows a Kids session on the same terms as an adult', async () => {
    const result = await useCase.execute({ ...TEST_ACTOR, role: MemberRole.KIDS });

    expect(result.memberId).toBe(TEST_ACTOR.memberId);
  });

  it('answers 404 if the session member no longer exists', async () => {
    profileRepository.findOwnProfile.mockResolvedValue(undefined);

    const error = await useCase.execute(TEST_ACTOR).catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
  });
});
