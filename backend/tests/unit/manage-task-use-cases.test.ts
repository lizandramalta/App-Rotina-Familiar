import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CreateTaskUseCase,
  DeleteTaskUseCase,
  EditTaskUseCase,
} from '../../src/modules/tasks/application/manage-task-use-cases.js';
import type {
  TaskRecord,
  TaskRepositoryPort,
} from '../../src/modules/tasks/application/task-repository-port.js';
import {
  MissionWouldHaveNoTasksError,
  SignalResolutionRequiredError,
  TaskManagementNotAllowedError,
} from '../../src/modules/tasks/domain/task-errors.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T12:00:00.000Z');
const TASK: TaskRecord = {
  id: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e',
  familyId: TEST_ACTOR.familyId,
  title: 'Arrumar os brinquedos',
  weight: 2,
  scheduledDate: '2026-10-10',
  note: null,
  status: 'pending',
  routineId: null,
  createdAt: NOW,
  assigneeIds: [TEST_ACTOR.memberId],
};

describe('Task management use cases — SPEC-007', () => {
  let repository: Record<keyof TaskRepositoryPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;

  beforeEach(() => {
    repository = {
      insertSingleTask: vi.fn().mockResolvedValue(TASK),
      findTask: vi.fn().mockResolvedValue(TASK),
      countFamilyMembers: vi.fn().mockResolvedValue(1),
      hasCompletedMission: vi.fn().mockResolvedValue(false),
      isOnlyTaskOfAnActiveMission: vi.fn().mockResolvedValue(false),
      hasCurrentSignal: vi.fn().mockResolvedValue(false),
      updateTask: vi.fn().mockResolvedValue(TASK),
      deleteTask: vi.fn(),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(
        async (_familyId: string, work: (tx: TransactionContext) => Promise<unknown>) =>
          work({ client: {} }),
      ),
    } as unknown as TransactionRunner;
  });

  const dependencies = () => ({
    repository: repository as unknown as TaskRepositoryPort,
    transactionRunner,
    clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
  });

  it('CA-01 creates a pending single task under the family lock', async () => {
    const result = await new CreateTaskUseCase(dependencies()).execute({
      actor: TEST_ACTOR,
      title: ' Arrumar os brinquedos ',
      weight: 2,
      scheduledDate: '2026-10-10',
      assigneeIds: [TEST_ACTOR.memberId, TEST_ACTOR.memberId],
      note: 'Guardar',
    });

    expect(result).toMatchObject({ id: TASK.id, status: 'pending' });
    expect(transactionRunner.forFamily).toHaveBeenCalledWith(
      TEST_ACTOR.familyId,
      expect.any(Function),
    );
    expect(repository.insertSingleTask).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        title: 'Arrumar os brinquedos',
        assigneeIds: [TEST_ACTOR.memberId],
        note: 'Guardar',
      }),
    );
  });

  it.each([
    [
      { ...TEST_ACTOR, role: MemberRole.KIDS },
      { title: 'Tarefa', weight: 1, scheduledDate: '2026-10-10' },
    ],
    [TEST_ACTOR, { title: '', weight: 1, scheduledDate: '2026-10-10' }],
    [TEST_ACTOR, { title: 'Tarefa', weight: 4, scheduledDate: '2026-10-10' }],
    [TEST_ACTOR, { title: 'Tarefa', weight: 1, scheduledDate: 'not-a-date' }],
  ])('CA-02/CA-04 rejects unauthorized or invalid creation', async (actor, input) => {
    const useCase = new CreateTaskUseCase(dependencies());
    await expect(
      useCase.execute({ actor, assigneeIds: [], note: null, ...input }),
    ).rejects.toBeInstanceOf(actor.role === 'kids' ? TaskManagementNotAllowedError : Error);
    expect(repository.insertSingleTask).not.toHaveBeenCalled();
  });

  it('CA-10 rejects an assignee outside the family', async () => {
    repository.countFamilyMembers.mockResolvedValue(0);
    const useCase = new CreateTaskUseCase(dependencies());
    await expect(
      useCase.execute({
        actor: TEST_ACTOR,
        title: 'Tarefa',
        weight: 1,
        scheduledDate: '2026-10-10',
        assigneeIds: ['external'],
        note: null,
      }),
    ).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { assigneeIds: ['ASSIGNEE_NOT_IN_FAMILY'] },
    });
  });

  it('CA-14 requires resolution when editing an awaiting-confirmation task', async () => {
    repository.findTask.mockResolvedValue({ ...TASK, status: 'awaitingConfirmation' });
    const useCase = new EditTaskUseCase(dependencies());
    await expect(
      useCase.execute({
        actor: TEST_ACTOR,
        taskId: TASK.id,
        title: 'Outro',
        weight: undefined,
        scheduledDate: undefined,
        assigneeIds: undefined,
        note: undefined,
        signalResolution: undefined,
      }),
    ).rejects.toBeInstanceOf(SignalResolutionRequiredError);
    expect(repository.updateTask).not.toHaveBeenCalled();
  });

  it('CA-12 resets a pending signal and persists the pending state', async () => {
    repository.findTask.mockResolvedValue({ ...TASK, status: 'awaitingConfirmation' });
    repository.hasCurrentSignal.mockResolvedValue(true);
    const useCase = new EditTaskUseCase(dependencies());
    await useCase.execute({
      actor: TEST_ACTOR,
      taskId: TASK.id,
      title: undefined,
      weight: undefined,
      scheduledDate: undefined,
      assigneeIds: undefined,
      note: 'Novo',
      signalResolution: 'resetToPending',
    });
    expect(repository.updateTask).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ status: 'pending', discardSignal: true }),
    );
  });

  it('CA-08 keeps the last linked task of an active mission', async () => {
    repository.isOnlyTaskOfAnActiveMission.mockResolvedValue(true);
    const useCase = new DeleteTaskUseCase(dependencies());
    await expect(useCase.execute(TEST_ACTOR, TASK.id)).rejects.toBeInstanceOf(
      MissionWouldHaveNoTasksError,
    );
    expect(repository.deleteTask).not.toHaveBeenCalled();
  });
});
