import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ReopenTaskUseCase } from '../../src/modules/tasks/application/reopen-task-use-case.js';
import type { TaskRepositoryPort } from '../../src/modules/tasks/application/task-repository-port.js';
import type { MissionReopeningPort } from '../../src/modules/tasks/application/mission-reopening-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');
const ACTOR: ActorContext = {
  sessionId: '00000000-0000-4000-8000-000000000001',
  familyId: '00000000-0000-4000-8000-000000000002',
  memberId: '00000000-0000-4000-8000-000000000003',
  role: MemberRole.ADMINISTRATOR,
  isFamilyCreator: true,
};
const TASK = {
  id: '00000000-0000-4000-8000-000000000004',
  familyId: ACTOR.familyId,
  title: 'Task',
  weight: 2,
  scheduledDate: '2026-10-09',
  note: null,
  status: 'completed' as const,
  routineId: null,
  createdAt: NOW,
  assigneeIds: [ACTOR.memberId],
};

describe('SCRUM-56 / SPEC-011 phase 1 — ReopenTask', () => {
  let tasks: { [K in keyof TaskRepositoryPort]: ReturnType<typeof vi.fn> };
  let missions: { [K in keyof MissionReopeningPort]: ReturnType<typeof vi.fn> };
  let useCase: ReopenTaskUseCase;

  beforeEach(() => {
    tasks = {
      insertTaskTemplate: vi.fn(),
      insertSingleTask: vi.fn(),
      findTask: vi.fn().mockResolvedValue(TASK),
      findMemberRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      countFamilyMembers: vi.fn(),
      hasCompletedMission: vi.fn(),
      isOnlyTaskOfAnActiveMission: vi.fn(),
      hasCurrentSignal: vi.fn(),
      hasKidsAssignee: vi.fn(),
      closeCurrentSignalByManualCompletion: vi.fn(),
      completeTask: vi.fn(),
      reopenTask: vi.fn().mockResolvedValue({ ...TASK, status: 'pending' }),
      updateTask: vi.fn(),
      deleteTask: vi.fn(),
    };
    missions = {
      findLinkedMissions: vi.fn().mockResolvedValue([]),
      reopenCompletedMissions: vi.fn().mockResolvedValue({
        participationsRemoved: 0,
        badgesRemoved: [],
        rewardRemoved: false,
      }),
    };
    const transactionRunner: TransactionRunner = {
      run: async <T>(work: (tx: TransactionContext) => Promise<T>) => work({ client: {} }),
      forFamily: async <T>(_familyId: string, work: (tx: TransactionContext) => Promise<T>) =>
        work({ client: {} }),
    };
    useCase = new ReopenTaskUseCase({
      tasks: tasks as unknown as TaskRepositoryPort,
      missions: missions as unknown as MissionReopeningPort,
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
      logger: createRecordingLogger().logger,
    });
  });

  it('CA-01 reopens without mission impact and retains all assignees', async () => {
    const result = await useCase.execute(ACTOR, TASK.id, false);
    expect(result.task).toMatchObject({ status: 'pending', assigneeIds: TASK.assigneeIds });
    expect(result.affectedResources).toEqual({
      missionsReopened: [],
      participationsRemoved: 0,
      badgesRemoved: [],
      rewardRemoved: false,
    });
    expect(tasks.reopenTask).toHaveBeenCalledOnce();
  });

  it('CA-02 requires confirmation before any mutation', async () => {
    missions.findLinkedMissions.mockResolvedValue([
      { id: 'mission-id', title: 'Mission', completed: true, hasAcceptedReward: false },
    ]);
    await expect(useCase.execute(ACTOR, TASK.id, false)).rejects.toMatchObject({
      code: 'MISSION_REOPEN_REQUIRES_CONFIRMATION',
      missionsAffected: [{ id: 'mission-id', title: 'Mission' }],
      hasAcceptedReward: false,
    });
    expect(tasks.reopenTask).not.toHaveBeenCalled();
    expect(missions.reopenCompletedMissions).not.toHaveBeenCalled();
  });

  it('CA-03 confirms a completed mission in the same transaction', async () => {
    missions.findLinkedMissions.mockResolvedValue([
      { id: 'mission-id', title: 'Mission', completed: true, hasAcceptedReward: false },
    ]);
    missions.reopenCompletedMissions.mockResolvedValue({
      participationsRemoved: 2,
      badgesRemoved: [{ memberId: ACTOR.memberId, tier: 'bronze' }],
      rewardRemoved: false,
    });
    const result = await useCase.execute(ACTOR, TASK.id, true);
    expect(result.affectedResources).toMatchObject({
      missionsReopened: [{ id: 'mission-id', title: 'Mission', status: 'inProgress' }],
      participationsRemoved: 2,
      badgesRemoved: [{ memberId: ACTOR.memberId, tier: 'bronze' }],
    });
    expect(tasks.reopenTask.mock.invocationCallOrder[0]).toBeLessThan(
      missions.reopenCompletedMissions.mock.invocationCallOrder[0] ?? 0,
    );
  });

  it('CA-04 permits Kids to reopen their own task', async () => {
    tasks.findMemberRole.mockResolvedValue(MemberRole.KIDS);
    await expect(
      useCase.execute({ ...ACTOR, role: MemberRole.KIDS }, TASK.id, false),
    ).resolves.toMatchObject({ task: { status: 'pending' } });
  });

  it('CA-01 permits a Member to reopen a family task after role revalidation', async () => {
    tasks.findMemberRole.mockResolvedValue(MemberRole.MEMBER);
    await expect(
      useCase.execute({ ...ACTOR, role: MemberRole.MEMBER }, TASK.id, false),
    ).resolves.toMatchObject({ task: { status: 'pending' } });
  });

  it('CA-05 denies Kids on a third-party task', async () => {
    tasks.findMemberRole.mockResolvedValue(MemberRole.KIDS);
    tasks.findTask.mockResolvedValue({ ...TASK, assigneeIds: [] });
    await expect(
      useCase.execute({ ...ACTOR, role: MemberRole.KIDS }, TASK.id, false),
    ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
    expect(tasks.reopenTask).not.toHaveBeenCalled();
  });

  it.each(['pending', 'awaitingConfirmation'])('CA-06 refuses a %s task', async (status) => {
    tasks.findTask.mockResolvedValue({ ...TASK, status });
    await expect(useCase.execute(ACTOR, TASK.id, false)).rejects.toMatchObject({
      code: 'TASK_NOT_COMPLETED',
    });
    expect(tasks.reopenTask).not.toHaveBeenCalled();
  });

  it('CA-07 conceals tasks outside the actor family', async () => {
    tasks.findTask.mockResolvedValue(undefined);
    await expect(useCase.execute(ACTOR, TASK.id, false)).rejects.toMatchObject({
      code: 'RESOURCE_NOT_FOUND',
    });
    expect(missions.findLinkedMissions).not.toHaveBeenCalled();
  });

  it('CA-01 reports an uncertain persistence failure as 503', async () => {
    tasks.reopenTask.mockRejectedValue(new Error('database connection lost'));
    await expect(useCase.execute(ACTOR, TASK.id, false)).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
      statusCode: 503,
    });
  });
});
