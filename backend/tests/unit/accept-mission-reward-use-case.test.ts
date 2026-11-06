import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AcceptMissionRewardUseCase } from '../../src/modules/missions/application/accept-mission-reward-use-case.js';
import type {
  MissionRecord,
  MissionRepositoryPort,
} from '../../src/modules/missions/application/mission-repository-port.js';
import type { RewardCatalogPort } from '../../src/modules/missions/application/reward-catalog-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-11-04T12:00:00.000Z');
const MISSION_ID = 'e4f5a6b7-c8d9-4123-8567-89abcdef0123';
const OTHER_FAMILY_MISSION_ID = 'c9d8e7f6-a5b4-4321-8765-43210fedcba9';
const REWARD_ITEM_ID = 'b2811e28-9ad3-4000-8000-000000000001';

const COMPLETED_MISSION: MissionRecord = {
  id: MISSION_ID,
  familyId: TEST_ACTOR.familyId,
  title: 'Arrumar o quintal',
  note: null,
  completedAt: NOW,
  createdAt: NOW,
  taskIds: ['9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e'],
  tasks: [{ id: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e', title: 'Lavar o carro', status: 'completed' }],
  acceptedReward: null,
};

const MEMBER_ACTOR = { ...TEST_ACTOR, role: MemberRole.MEMBER, isFamilyCreator: false };
const KIDS_ACTOR = { ...TEST_ACTOR, role: MemberRole.KIDS, isFamilyCreator: false };

describe('AcceptMissionRewardUseCase — SPEC-017 phase 1', () => {
  let repository: Record<keyof MissionRepositoryPort, ReturnType<typeof vi.fn>>;
  let rewardCatalog: Record<keyof RewardCatalogPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;
  let forFamily: ReturnType<typeof vi.fn>;
  const logger = { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() };

  beforeEach(() => {
    vi.clearAllMocks();
    repository = {
      findMemberRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      countFamilyTasks: vi.fn(),
      insertMission: vi.fn(),
      findMission: vi.fn().mockResolvedValue(COMPLETED_MISSION),
      updateMission: vi.fn(),
      listMissions: vi.fn(),
      listParticipations: vi.fn(),
      listTaskOptions: vi.fn(),
      closeEligible: vi.fn(),
      findMissionIdsByTask: vi.fn(),
      acceptReward: vi.fn().mockResolvedValue(true),
    };
    rewardCatalog = {
      findEligibleItem: vi.fn().mockResolvedValue({
        id: REWARD_ITEM_ID,
        title: 'Escolher o filme da noite',
        details: null,
        source: 'predefined',
      }),
    };
    forFamily = vi.fn(
      async (_familyId: string, work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} } as unknown as TransactionContext),
    );
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} } as unknown as TransactionContext),
      ),
      forFamily,
    } as unknown as TransactionRunner;
  });

  const build = () =>
    new AcceptMissionRewardUseCase({
      repository: repository as unknown as MissionRepositoryPort,
      rewardCatalog: rewardCatalog as unknown as RewardCatalogPort,
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
      logger: logger as never,
    });
  const command = (overrides: Record<string, unknown> = {}) => ({
    actor: TEST_ACTOR,
    missionId: MISSION_ID,
    rewardItemId: REWARD_ITEM_ID,
    ...overrides,
  });

  it('CA-01 accepts an eligible item for a completed mission under the family lock', async () => {
    repository.findMission
      .mockResolvedValueOnce(COMPLETED_MISSION)
      .mockResolvedValueOnce({
        ...COMPLETED_MISSION,
        acceptedReward: {
          rewardItemId: REWARD_ITEM_ID,
          title: 'Escolher o filme da noite',
          details: null,
          source: 'predefined',
          acceptedAt: NOW,
        },
      });

    const result = await build().execute(command());

    expect(forFamily).toHaveBeenCalledWith(TEST_ACTOR.familyId, expect.any(Function));
    expect(repository.acceptReward).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        missionId: MISSION_ID,
        reward: { id: REWARD_ITEM_ID, title: 'Escolher o filme da noite', details: null, source: 'predefined' },
        now: NOW,
      }),
    );
    expect(result).toMatchObject({
      status: 'completed',
      acceptedReward: { rewardItemId: REWARD_ITEM_ID, source: 'predefined' },
    });
    expect(logger.info).toHaveBeenCalledWith(
      'mission_reward_accepted',
      expect.objectContaining({
        missionId: MISSION_ID,
        familyId: TEST_ACTOR.familyId,
        rewardItemId: REWARD_ITEM_ID,
        rewardSource: 'predefined',
      }),
    );
  });

  it.each([
    ['Membro', MEMBER_ACTOR],
    ['Kids', KIDS_ACTOR],
  ])('CA-02 refuses %s without opening a transaction', async (_name, actor) => {
    await expect(build().execute(command({ actor }))).rejects.toMatchObject({
      code: 'INSUFFICIENT_PERMISSIONS',
    });
    expect(forFamily).not.toHaveBeenCalled();
    expect(repository.acceptReward).not.toHaveBeenCalled();
  });

  it('CA-02 re-reads the role under the lock and refuses a demoted session', async () => {
    repository.findMemberRole.mockResolvedValue(MemberRole.MEMBER);

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'INSUFFICIENT_PERMISSIONS',
    });
    expect(repository.acceptReward).not.toHaveBeenCalled();
  });

  it('CA-03 hides a mission of another family as not found', async () => {
    repository.findMission.mockResolvedValue(undefined);

    await expect(
      build().execute(command({ missionId: OTHER_FAMILY_MISSION_ID })),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    expect(repository.acceptReward).not.toHaveBeenCalled();
  });

  it.each([['not-a-uuid'], [''], [123], [null], [undefined]])(
    'CA-03 rejects a malformed rewardItemId (%j) without querying the database',
    async (rewardItemId) => {
      await expect(build().execute(command({ rewardItemId }))).rejects.toMatchObject({
        code: 'REWARD_ITEM_NOT_ELIGIBLE',
        fieldErrors: { rewardItemId: ['REWARD_ITEM_NOT_ELIGIBLE'] },
      });
      expect(forFamily).not.toHaveBeenCalled();
      expect(rewardCatalog.findEligibleItem).not.toHaveBeenCalled();
    },
  );

  it('CA-03 rejects an item not eligible for the family without revealing another family item', async () => {
    rewardCatalog.findEligibleItem.mockResolvedValue(undefined);

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'REWARD_ITEM_NOT_ELIGIBLE',
      fieldErrors: { rewardItemId: ['REWARD_ITEM_NOT_ELIGIBLE'] },
    });
    expect(repository.acceptReward).not.toHaveBeenCalled();
  });

  it('CA-04 refuses an in-progress mission without mutating state', async () => {
    repository.findMission.mockResolvedValue({ ...COMPLETED_MISSION, completedAt: null });

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'MISSION_REWARD_REDEMPTION_UNAVAILABLE',
    });
    expect(repository.acceptReward).not.toHaveBeenCalled();
    expect(rewardCatalog.findEligibleItem).not.toHaveBeenCalled();
  });

  it('guards against a mission that already has an accepted reward', async () => {
    repository.findMission.mockResolvedValue({
      ...COMPLETED_MISSION,
      acceptedReward: {
        rewardItemId: REWARD_ITEM_ID,
        title: 'Noite de jogos em família',
        details: null,
        source: 'predefined',
        acceptedAt: NOW,
      },
    });

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'MISSION_REWARD_ALREADY_ACCEPTED',
    });
    expect(repository.acceptReward).not.toHaveBeenCalled();
  });

  it('maps a lost conditional write to MISSION_REWARD_ALREADY_ACCEPTED', async () => {
    repository.acceptReward.mockResolvedValue(false);

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'MISSION_REWARD_ALREADY_ACCEPTED',
    });
  });

  it('translates unexpected persistence failures into DEPENDENCY_UNAVAILABLE', async () => {
    repository.acceptReward.mockRejectedValue(new Error('connection reset'));

    await expect(build().execute(command())).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
    });
  });
});
