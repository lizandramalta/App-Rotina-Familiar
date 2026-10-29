import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CloseEligibleMissions } from '../../src/modules/missions/application/close-eligible-missions.js';
import type {
  MissionRecord,
  MissionRepositoryPort,
} from '../../src/modules/missions/application/mission-repository-port.js';
import {
  CreateMissionUseCase,
  EditMissionUseCase,
  GetMissionDetailUseCase,
  GetMissionTaskOptionsUseCase,
  ListMissionsUseCase,
} from '../../src/modules/missions/application/mission-use-cases.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-19T12:00:00.000Z');
const TASK_A = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const TASK_B = 'b2c3d4e5-f6a7-4901-8cde-f12345678901';
const MISSION_ID = 'e4f5a6b7-c8d9-4123-8567-89abcdef0123';

const MISSION: MissionRecord = {
  id: MISSION_ID,
  familyId: TEST_ACTOR.familyId,
  title: 'Arrumar o quintal',
  note: null,
  completedAt: null,
  createdAt: NOW,
  taskIds: [TASK_A, TASK_B],
  tasks: [
    { id: TASK_A, title: 'Lavar o carro', status: 'pending' },
    { id: TASK_B, title: 'Cortar a grama', status: 'pending' },
  ],
};

const MEMBER_ACTOR = { ...TEST_ACTOR, role: MemberRole.MEMBER, isFamilyCreator: false };
const KIDS_ACTOR = { ...TEST_ACTOR, role: MemberRole.KIDS, isFamilyCreator: false };

describe('Mission use cases — SPEC-014 phase 1', () => {
  let repository: Record<keyof MissionRepositoryPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;
  let forFamily: ReturnType<typeof vi.fn>;
  const logger = { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() };

  beforeEach(() => {
    vi.clearAllMocks();
    repository = {
      findMemberRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      countFamilyTasks: vi.fn().mockImplementation(async (_tx, _family, ids) => ids.length),
      insertMission: vi.fn().mockResolvedValue(undefined),
      findMission: vi.fn().mockResolvedValue(MISSION),
      updateMission: vi.fn().mockResolvedValue(undefined),
      listMissions: vi.fn().mockResolvedValue([]),
      listParticipations: vi.fn().mockResolvedValue([]),
      listTaskOptions: vi.fn().mockResolvedValue([]),
      closeEligible: vi.fn().mockResolvedValue([]),
      findMissionIdsByTask: vi.fn().mockResolvedValue([]),
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

  const base = () => ({
    repository: repository as unknown as MissionRepositoryPort,
    transactionRunner,
    clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    logger: logger as never,
  });
  const closer = () =>
    new CloseEligibleMissions({
      repository: repository as unknown as MissionRepositoryPort,
      logger: logger as never,
    });
  const create = () => new CreateMissionUseCase({ ...base(), closer: closer() });
  const edit = () => new EditMissionUseCase({ ...base(), closer: closer() });
  const createCommand = (overrides: Record<string, unknown> = {}) => ({
    actor: TEST_ACTOR,
    title: ' Arrumar o quintal ',
    note: undefined,
    taskIds: [TASK_A, TASK_B],
    ...overrides,
  });

  it('CA-01 creates an in-progress mission under the family lock', async () => {
    const result = await create().execute(createCommand());

    expect(forFamily).toHaveBeenCalledWith(TEST_ACTOR.familyId, expect.any(Function));
    expect(repository.insertMission).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        title: 'Arrumar o quintal',
        note: null,
        taskIds: [TASK_A, TASK_B],
        now: NOW,
      }),
    );
    expect(result).toMatchObject({
      status: 'inProgress',
      completedAt: null,
      isRedemptionAvailable: false,
    });
  });

  it.each([
    ['Membro', MEMBER_ACTOR],
    ['Kids', KIDS_ACTOR],
  ])('CA-02 refuses mission creation by %s without opening a transaction', async (_name, actor) => {
    await expect(create().execute(createCommand({ actor }))).rejects.toMatchObject({
      code: 'ACTION_NOT_ALLOWED',
    });
    expect(forFamily).not.toHaveBeenCalled();
    expect(repository.insertMission).not.toHaveBeenCalled();
  });

  it('CA-02 re-reads the role under the lock and refuses a demoted session', async () => {
    repository.findMemberRole.mockResolvedValue(MemberRole.MEMBER);

    await expect(create().execute(createCommand())).rejects.toMatchObject({
      code: 'ACTION_NOT_ALLOWED',
    });
    expect(repository.insertMission).not.toHaveBeenCalled();
  });

  it.each([
    ['Membro', MEMBER_ACTOR],
    ['Kids', KIDS_ACTOR],
  ])('CA-03 refuses mission edition by %s', async (_name, actor) => {
    await expect(
      edit().execute({ ...createCommand({ actor }), missionId: MISSION_ID }),
    ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
    expect(repository.updateMission).not.toHaveBeenCalled();
  });

  it('CA-04 hides a mission of another family as not found', async () => {
    repository.findMission.mockResolvedValue(undefined);

    await expect(
      new GetMissionDetailUseCase(base()).execute(TEST_ACTOR, MISSION_ID),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    await expect(
      edit().execute({ ...createCommand(), missionId: MISSION_ID }),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    expect(repository.updateMission).not.toHaveBeenCalled();
  });

  it.each([[undefined], [[]]])('CA-05 requires tasks on creation (%j)', async (taskIds) => {
    await expect(create().execute(createCommand({ taskIds }))).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { taskIds: ['MISSION_TASKS_REQUIRED'] },
    });
    expect(repository.insertMission).not.toHaveBeenCalled();
  });

  it.each([[''], ['   '], ['x'.repeat(61)]])(
    'CA-06 rejects a title outside 1..60 visible characters',
    async (title) => {
      await expect(create().execute(createCommand({ title }))).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
      });
      expect(repository.insertMission).not.toHaveBeenCalled();
    },
  );

  it('CA-06 accepts exactly 60 visible characters counted by grapheme', async () => {
    await expect(
      create().execute(createCommand({ title: '👨‍👩‍👧'.repeat(60) })),
    ).resolves.toBeDefined();
  });

  it('CA-07 refuses a task from another family without revealing it', async () => {
    repository.countFamilyTasks.mockResolvedValue(1);

    await expect(create().execute(createCommand())).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { taskIds: ['TASK_NOT_IN_FAMILY'] },
    });
    expect(repository.insertMission).not.toHaveBeenCalled();
  });

  it('CA-07 deduplicates repeated task ids before validating membership', async () => {
    await create().execute(createCommand({ taskIds: [TASK_A, TASK_A.toUpperCase(), TASK_B] }));

    expect(repository.countFamilyTasks).toHaveBeenCalledWith(
      expect.anything(),
      TEST_ACTOR.familyId,
      [TASK_A, TASK_B],
    );
  });

  it('CA-08 refuses a note above 250 characters on creation and edition', async () => {
    const note = 'n'.repeat(251);

    await expect(create().execute(createCommand({ note }))).rejects.toMatchObject({
      fieldErrors: { note: ['NOTE_TOO_LONG'] },
    });
    await expect(
      edit().execute({ ...createCommand({ note }), missionId: MISSION_ID }),
    ).rejects.toMatchObject({ fieldErrors: { note: ['NOTE_TOO_LONG'] } });
  });

  it('CA-09 edit preserves omitted fields and null removes the note', async () => {
    repository.findMission.mockResolvedValue({ ...MISSION, note: 'Antes do churrasco' });

    await edit().execute({
      actor: TEST_ACTOR,
      missionId: MISSION_ID,
      title: undefined,
      note: null,
      taskIds: undefined,
    });

    expect(repository.updateMission).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ title: MISSION.title, note: null, taskIds: MISSION.taskIds }),
    );
  });

  it('CA-10 protects a completed mission from edition', async () => {
    repository.findMission.mockResolvedValue({ ...MISSION, completedAt: NOW });

    await expect(
      edit().execute({ ...createCommand(), missionId: MISSION_ID }),
    ).rejects.toMatchObject({ code: 'MISSION_COMPLETED_PROTECTED' });
    expect(repository.updateMission).not.toHaveBeenCalled();
  });

  it('CA-11 refuses an edit that would leave the mission without tasks', async () => {
    await expect(
      edit().execute({
        actor: TEST_ACTOR,
        missionId: MISSION_ID,
        title: undefined,
        note: undefined,
        taskIds: [],
      }),
    ).rejects.toMatchObject({ code: 'MISSION_WOULD_HAVE_NO_TASKS' });
    expect(repository.updateMission).not.toHaveBeenCalled();
  });

  it('CA-13 creation reports a mission closed in the same transaction', async () => {
    repository.closeEligible.mockResolvedValue([
      { missionId: MISSION_ID, participationCount: 2, badgesAwardedCount: 1 },
    ]);
    repository.findMission.mockResolvedValue({ ...MISSION, completedAt: NOW });

    const result = await create().execute(createCommand());

    expect(repository.closeEligible).toHaveBeenCalledTimes(1);
    expect(repository.closeEligible).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ familyId: TEST_ACTOR.familyId, now: NOW }),
    );
    expect(result).toMatchObject({ status: 'completed', isRedemptionAvailable: true });
    expect(logger.info).toHaveBeenCalledWith(
      'mission_closed',
      expect.objectContaining({ participationCount: 2, badgesAwardedCount: 1, trigger: 'create' }),
    );
  });

  it('CA-14 edition triggers the closing check for the edited mission', async () => {
    await edit().execute({
      actor: TEST_ACTOR,
      missionId: MISSION_ID,
      title: undefined,
      note: undefined,
      taskIds: [TASK_A],
    });

    expect(repository.closeEligible).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ missionIds: [MISSION_ID] }),
    );
  });

  it('CA-15 CompleteTask hook closes every mission linking the task, once each', async () => {
    repository.findMissionIdsByTask.mockResolvedValue([MISSION_ID, MISSION_ID, TASK_A]);

    await closer().closeForCompletedTask({ client: {} } as unknown as TransactionContext, {
      familyId: TEST_ACTOR.familyId,
      taskId: TASK_A,
      now: NOW,
    });

    expect(repository.closeEligible).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      missionIds: [MISSION_ID, TASK_A].sort(),
      now: NOW,
    });
  });

  it('CA-15 does not touch the repository when no mission links the task', async () => {
    await closer().closeForCompletedTask({ client: {} } as unknown as TransactionContext, {
      familyId: TEST_ACTOR.familyId,
      taskId: TASK_A,
      now: NOW,
    });

    expect(repository.closeEligible).not.toHaveBeenCalled();
  });

  it('CA-03 shapes the Kids detail without participations or redemption status', async () => {
    const result = await new GetMissionDetailUseCase(base()).execute(KIDS_ACTOR, MISSION_ID);

    expect(result).not.toHaveProperty('isRedemptionAvailable');
    expect(result).not.toHaveProperty('familyId');
    expect(result).not.toHaveProperty('participations');
    expect(repository.listParticipations).not.toHaveBeenCalled();
    expect(result).toMatchObject({
      title: MISSION.title,
      tasks: MISSION.tasks,
      progressPercent: 0,
      acceptedReward: null,
    });
  });

  it('CA-03 detail for Administrator/Membro includes participations and redemption status', async () => {
    repository.listParticipations.mockResolvedValue([
      { memberId: 'a1000000-0000-4000-8000-000000000001', displayName: 'Ana' },
    ]);
    repository.findMission.mockResolvedValue({ ...MISSION, completedAt: NOW });

    const result = await new GetMissionDetailUseCase(base()).execute(TEST_ACTOR, MISSION_ID);

    expect(repository.listParticipations).toHaveBeenCalledWith(
      expect.anything(),
      TEST_ACTOR.familyId,
      MISSION_ID,
    );
    expect(result).toMatchObject({
      isRedemptionAvailable: true,
      acceptedReward: null,
      participations: [{ memberId: 'a1000000-0000-4000-8000-000000000001', displayName: 'Ana' }],
    });
  });

  it('CA-02 excludes an awaitingConfirmation task from the completed count', async () => {
    repository.findMission.mockResolvedValue({
      ...MISSION,
      tasks: [
        { id: TASK_A, title: 'Lavar o carro', status: 'completed' },
        { id: TASK_B, title: 'Cortar a grama', status: 'awaitingConfirmation' },
      ],
    });

    const result = await new GetMissionDetailUseCase(base()).execute(TEST_ACTOR, MISSION_ID);

    expect(result).toMatchObject({ status: 'inProgress', progressPercent: 50 });
  });

  it('CA-01/CA-02 lists missions grouped by in-progress/completed with canonical progress', async () => {
    repository.listMissions.mockResolvedValue([
      {
        id: '00000000-0000-4000-8000-000000000001',
        title: 'Em andamento',
        completedAt: null,
        createdAt: NOW,
        taskCount: 2,
        completedTaskCount: 1,
      },
      {
        id: '00000000-0000-4000-8000-000000000002',
        title: 'Concluída',
        completedAt: NOW,
        createdAt: NOW,
        taskCount: 2,
        completedTaskCount: 2,
      },
    ]);

    const result = await new ListMissionsUseCase(base()).execute(TEST_ACTOR);

    expect(result.inProgress).toEqual([
      expect.objectContaining({
        id: '00000000-0000-4000-8000-000000000001',
        progressPercent: 50,
        isRedemptionAvailable: false,
        acceptedReward: null,
      }),
    ]);
    expect(result.completed).toEqual([
      expect.objectContaining({
        id: '00000000-0000-4000-8000-000000000002',
        progressPercent: 100,
        isRedemptionAvailable: true,
        acceptedReward: null,
      }),
    ]);
  });

  it('CA-03 Kids list items omit isRedemptionAvailable', async () => {
    repository.listMissions.mockResolvedValue([
      {
        id: '00000000-0000-4000-8000-000000000001',
        title: 'Em andamento',
        completedAt: null,
        createdAt: NOW,
        taskCount: 2,
        completedTaskCount: 1,
      },
    ]);

    const result = await new ListMissionsUseCase(base()).execute(KIDS_ACTOR);

    expect(result.inProgress[0]).not.toHaveProperty('isRedemptionAvailable');
    expect(result.inProgress[0]).toMatchObject({ progressPercent: 50, acceptedReward: null });
  });

  it('restricts task options to administrators', async () => {
    await expect(
      new GetMissionTaskOptionsUseCase(base()).execute(MEMBER_ACTOR, undefined, undefined),
    ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
  });

  it('translates unexpected persistence failures into DEPENDENCY_UNAVAILABLE', async () => {
    repository.insertMission.mockRejectedValue(new Error('connection reset'));

    await expect(create().execute(createCommand())).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
    });
  });
});
