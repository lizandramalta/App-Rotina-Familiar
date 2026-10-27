import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  DeleteFutureRoutineTasksUseCase,
  UpdateFutureRoutineUseCase,
} from '../../src/modules/routines/application/manage-routine-use-cases.js';
import type { RoutineRecord } from '../../src/modules/routines/application/routine-repository-port.js';
import type { RoutineRepositoryPort } from '../../src/modules/routines/application/routine-repository-port.js';
import type { TaskRepositoryPort } from '../../src/modules/tasks/application/task-repository-port.js';
import type { FamilySettingsRepositoryPort } from '../../src/modules/family/application/family-settings-repository-port.js';
import type { MissionClosurePort } from '../../src/modules/tasks/application/mission-closure-port.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type { Logger } from '../../src/shared/infrastructure/observability/logger.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const FAMILY_ID = '10000000-0000-4000-8000-000000000001';
const MEMBER_ID = '10000000-0000-4000-8000-000000000002';
const ROUTINE_ID = '10000000-0000-4000-8000-000000000003';
const SOURCE_ID = '10000000-0000-4000-8000-000000000004';
const FUTURE_ID = '10000000-0000-4000-8000-000000000005';
const PROTECTED_ID = '10000000-0000-4000-8000-000000000006';
const NOW = new Date('2026-10-27T12:00:00.000Z');

const actor: ActorContext = {
  sessionId: '10000000-0000-4000-8000-000000000007',
  familyId: FAMILY_ID,
  memberId: MEMBER_ID,
  role: MemberRole.ADMINISTRATOR,
  isFamilyCreator: true,
};

const routine: RoutineRecord = {
  id: ROUTINE_ID,
  familyId: FAMILY_ID,
  taskTemplateId: '10000000-0000-4000-8000-000000000008',
  title: 'Old routine',
  weight: 1,
  note: null,
  assigneeIds: [MEMBER_ID],
  frequencyDays: 7,
  startDate: '2026-10-01',
  isActive: true,
  generatedUntil: '2026-11-30',
  createdAt: NOW,
};

function occurrence(
  id: string,
  originalDate: string,
  options: {
    status?: 'pending' | 'awaitingConfirmation' | 'completed';
    isProtected?: boolean;
    scheduledDate?: string;
  } = {},
) {
  return {
    id,
    routineId: ROUTINE_ID,
    originalDate,
    scheduledDate: options.scheduledDate ?? originalDate,
    status: options.status ?? 'pending',
    isProtected: options.isProtected ?? false,
  };
}

describe('SPEC-008 phase 2 routine management — SCRUM-45', () => {
  let routines: Record<keyof RoutineRepositoryPort, ReturnType<typeof vi.fn>>;
  let tasks: {
    findMemberRole: ReturnType<typeof vi.fn>;
    countFamilyMembers: ReturnType<typeof vi.fn>;
  };
  let missionCloser: { closeAfterTaskDeletion: ReturnType<typeof vi.fn> };
  let update: UpdateFutureRoutineUseCase;
  let end: DeleteFutureRoutineTasksUseCase;

  beforeEach(() => {
    routines = {
      insertRoutine: vi.fn(),
      findRoutine: vi.fn().mockResolvedValue(routine),
      materializeBatch: vi.fn(),
      findSourceOccurrence: vi.fn().mockResolvedValue(occurrence(SOURCE_ID, '2026-10-08')),
      listFutureOccurrences: vi
        .fn()
        .mockResolvedValue([
          occurrence(SOURCE_ID, '2026-10-08'),
          occurrence(FUTURE_ID, '2026-10-15', { scheduledDate: '2026-12-01' }),
          occurrence(PROTECTED_ID, '2026-10-22', { isProtected: true }),
        ]),
      updateConfiguration: vi.fn().mockResolvedValue(undefined),
      updateOccurrences: vi.fn().mockResolvedValue(undefined),
      wouldEmptyActiveMission: vi.fn().mockResolvedValue(false),
      deleteOccurrences: vi.fn().mockResolvedValue(['10000000-0000-4000-8000-000000000009']),
      endGeneration: vi.fn().mockResolvedValue(undefined),
    };
    tasks = {
      findMemberRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      countFamilyMembers: vi.fn().mockResolvedValue(1),
    };
    missionCloser = { closeAfterTaskDeletion: vi.fn().mockResolvedValue(undefined) };
    const transactionRunner: TransactionRunner = {
      run: vi.fn(),
      forFamily: vi.fn(
        async (_familyId: string, work: (tx: TransactionContext) => Promise<unknown>) =>
          work({ client: {} }),
      ),
    } as unknown as TransactionRunner;
    const clock: Clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };
    const logger = { info: vi.fn() } as unknown as Logger;
    update = new UpdateFutureRoutineUseCase({
      routineRepository: routines as unknown as RoutineRepositoryPort,
      taskRepository: tasks as unknown as TaskRepositoryPort,
      familySettingsRepository: {
        findFamilyTimeZone: vi.fn().mockResolvedValue('America/Sao_Paulo'),
      } as unknown as FamilySettingsRepositoryPort,
      transactionRunner,
      clock,
      logger,
    });
    end = new DeleteFutureRoutineTasksUseCase({
      routineRepository: routines as unknown as RoutineRepositoryPort,
      taskRepository: tasks as unknown as TaskRepositoryPort,
      missionCloser: missionCloser as unknown as MissionClosurePort,
      transactionRunner,
      clock,
      logger,
    });
  });

  it('CA-07 updates eligible occurrences by original date and preserves protected ones', async () => {
    const result = await update.execute({
      actor,
      routineId: ROUTINE_ID,
      fromTaskId: SOURCE_ID,
      title: 'New routine',
      weight: 2,
      assigneeIds: [],
      note: 'New note',
    });
    expect(routines.listFutureOccurrences).toHaveBeenCalledWith(
      expect.anything(),
      FAMILY_ID,
      ROUTINE_ID,
      '2026-10-08',
      routine.taskTemplateId,
    );
    expect(routines.updateOccurrences).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        taskIds: [SOURCE_ID, FUTURE_ID],
        title: 'New routine',
        weight: 2,
        assigneeIds: [],
        note: 'New note',
      }),
    );
    expect(result.updatedTaskIds).toEqual([SOURCE_ID, FUTURE_ID]);
    expect(result.preservedTaskIds).toEqual([PROTECTED_ID]);
    expect(result.routine.startDate).toBe(routine.startDate);
    expect(result.routine.frequencyDays).toBe(routine.frequencyDays);
  });

  it('CA-07 refuses a protected source without changing configuration', async () => {
    routines.findSourceOccurrence.mockResolvedValue(
      occurrence(SOURCE_ID, '2026-10-08', { isProtected: true }),
    );
    await expect(
      update.execute({
        actor,
        routineId: ROUTINE_ID,
        fromTaskId: SOURCE_ID,
        title: 'New',
        weight: undefined,
        assigneeIds: undefined,
        note: undefined,
      }),
    ).rejects.toMatchObject({ statusCode: 409, code: 'MISSION_COMPLETED_PROTECTED' });
    expect(routines.updateConfiguration).not.toHaveBeenCalled();
  });

  it('CA-08 preserves completed/protected tasks and closes affected missions before ending generation', async () => {
    routines.listFutureOccurrences.mockResolvedValue([
      occurrence(SOURCE_ID, '2026-10-08'),
      occurrence(FUTURE_ID, '2026-10-15', { status: 'completed' }),
      occurrence(PROTECTED_ID, '2026-10-22', { isProtected: true }),
    ]);
    const result = await end.execute({ actor, routineId: ROUTINE_ID, fromTaskId: SOURCE_ID });
    expect(result).toEqual({
      routineId: ROUTINE_ID,
      deletedTaskIds: [SOURCE_ID],
      preservedTaskIds: [FUTURE_ID, PROTECTED_ID],
      generationEnded: true,
    });
    expect(routines.wouldEmptyActiveMission).toHaveBeenCalledWith(expect.anything(), FAMILY_ID, [
      SOURCE_ID,
    ]);
    expect(missionCloser.closeAfterTaskDeletion).toHaveBeenCalledBefore(routines.endGeneration);
  });

  it('CA-08 refuses deletion that would empty an active mission without writing', async () => {
    routines.wouldEmptyActiveMission.mockResolvedValue(true);
    await expect(
      end.execute({ actor, routineId: ROUTINE_ID, fromTaskId: SOURCE_ID }),
    ).rejects.toMatchObject({ statusCode: 409, code: 'MISSION_WOULD_HAVE_NO_TASKS' });
    expect(routines.deleteOccurrences).not.toHaveBeenCalled();
    expect(routines.endGeneration).not.toHaveBeenCalled();
  });

  it('CA-09 rejects a source from a different routine in the same family', async () => {
    routines.findSourceOccurrence.mockResolvedValue({
      ...occurrence(SOURCE_ID, '2026-10-08'),
      routineId: '10000000-0000-4000-8000-000000000010',
    });
    await expect(
      update.execute({
        actor,
        routineId: ROUTINE_ID,
        fromTaskId: SOURCE_ID,
        title: undefined,
        weight: undefined,
        assigneeIds: undefined,
        note: undefined,
      }),
    ).rejects.toMatchObject({
      statusCode: 422,
      fieldErrors: { fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'] },
    });
    await expect(
      end.execute({ actor, routineId: ROUTINE_ID, fromTaskId: SOURCE_ID }),
    ).rejects.toMatchObject({
      statusCode: 422,
      fieldErrors: { fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'] },
    });
    expect(routines.updateConfiguration).not.toHaveBeenCalled();
    expect(routines.endGeneration).not.toHaveBeenCalled();
  });

  it('CA-03/04 denies Kids and hides a source outside the family', async () => {
    await expect(
      end.execute({
        actor: { ...actor, role: MemberRole.KIDS },
        routineId: ROUTINE_ID,
        fromTaskId: SOURCE_ID,
      }),
    ).rejects.toMatchObject({ statusCode: 403, code: 'ACTION_NOT_ALLOWED' });
    routines.findSourceOccurrence.mockResolvedValue(undefined);
    await expect(
      end.execute({ actor, routineId: ROUTINE_ID, fromTaskId: SOURCE_ID }),
    ).rejects.toMatchObject({ statusCode: 404, code: 'RESOURCE_NOT_FOUND' });
    expect(routines.endGeneration).not.toHaveBeenCalled();
  });
});
