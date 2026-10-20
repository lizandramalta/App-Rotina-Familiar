/** Caso de uso `CreateRoutine` (SPEC-008 Fase 1 / SCRUM-43): CA-01 a CA-03, CA-05. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CreateRoutineUseCase,
  type RoutineResponse,
} from '../../src/modules/routines/application/create-routine-use-case.js';
import { MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH } from '../../src/modules/routines/application/routine-repository-port.js';
import type { RoutineRepositoryPort } from '../../src/modules/routines/application/routine-repository-port.js';
import type { FamilySettingsRepositoryPort } from '../../src/modules/family/application/family-settings-repository-port.js';
import type { TaskRepositoryPort } from '../../src/modules/tasks/application/task-repository-port.js';
import { ActionNotAllowedError, ValidationError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T12:00:00.000Z');

describe('CreateRoutineUseCase — SPEC-008', () => {
  let taskRepository: Record<'insertTaskTemplate' | 'countFamilyMembers', ReturnType<typeof vi.fn>>;
  let routineRepository: Record<keyof RoutineRepositoryPort, ReturnType<typeof vi.fn>>;
  let familySettingsRepository: { findFamilyTimeZone: ReturnType<typeof vi.fn> };
  let transactionRunner: TransactionRunner;
  let useCase: CreateRoutineUseCase;

  beforeEach(() => {
    taskRepository = {
      insertTaskTemplate: vi.fn().mockResolvedValue(undefined),
      countFamilyMembers: vi.fn().mockResolvedValue(1),
    };
    routineRepository = {
      insertRoutine: vi.fn().mockResolvedValue(undefined),
      findRoutine: vi.fn(),
      materializeBatch: vi
        .fn()
        .mockResolvedValue({ generatedUntil: '2026-11-30', isComplete: true }),
    };
    familySettingsRepository = {
      findFamilyTimeZone: vi.fn().mockResolvedValue('America/Sao_Paulo'),
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

    useCase = new CreateRoutineUseCase({
      taskRepository: taskRepository as unknown as TaskRepositoryPort,
      routineRepository: routineRepository as unknown as RoutineRepositoryPort,
      familySettingsRepository: familySettingsRepository as unknown as FamilySettingsRepositoryPort,
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
  });

  const validCommand = (
    overrides: Partial<Parameters<CreateRoutineUseCase['execute']>[0]> = {},
  ) => ({
    actor: TEST_ACTOR,
    title: 'Separar recicláveis',
    weight: 2,
    assigneeIds: [TEST_ACTOR.memberId],
    note: 'Lavar as embalagens antes',
    startDate: '2026-10-10',
    frequencyDays: 7,
    ...overrides,
  });

  it('CA-01 creates the routine under the family lock and starts materialization', async () => {
    const result: RoutineResponse = await useCase.execute(validCommand());

    expect(transactionRunner.forFamily).toHaveBeenCalledWith(
      TEST_ACTOR.familyId,
      expect.any(Function),
    );
    expect(taskRepository.insertTaskTemplate).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        title: 'Separar recicláveis',
        weight: 2,
        note: 'Lavar as embalagens antes',
        now: NOW,
      }),
    );
    expect(routineRepository.insertRoutine).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        frequencyDays: 7,
        startDate: '2026-10-10',
        assigneeIds: [TEST_ACTOR.memberId],
        now: NOW,
      }),
    );
    expect(routineRepository.materializeBatch).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        horizon: '2026-11-30',
        maxBatch: MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
        now: NOW,
      }),
    );
    expect(result).toMatchObject({
      title: 'Separar recicláveis',
      weight: 2,
      assigneeIds: [TEST_ACTOR.memberId],
      note: 'Lavar as embalagens antes',
      startDate: '2026-10-10',
      frequencyDays: 7,
      isActive: true,
      materializationState: 'complete',
    });
    expect(typeof result.id).toBe('string');
  });

  it('CA-01 accepts creation without note/assignees, saving without exigir data final', async () => {
    const result = await useCase.execute(validCommand({ note: undefined, assigneeIds: undefined }));

    expect(result.note).toBeNull();
    expect(result.assigneeIds).toEqual([]);
    expect(routineRepository.insertRoutine).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ assigneeIds: [] }),
    );
  });

  it('CA-05 reports materializationState: pending when the batch did not reach the horizon', async () => {
    routineRepository.materializeBatch.mockResolvedValue({
      generatedUntil: '2026-10-24',
      isComplete: false,
    });

    const result = await useCase.execute(validCommand());

    expect(result.materializationState).toBe('pending');
  });

  it.each([
    ['frequencyDays', { frequencyDays: 3 }, 'FREQUENCY_DAYS_INVALID'],
    ['startDate', { startDate: 'not-a-date' }, 'START_DATE_INVALID'],
  ])('CA-02 rejects invalid %s without persisting', async (field, overrides, code) => {
    const error = await useCase.execute(validCommand(overrides)).catch((e) => e);

    expect(error).toBeInstanceOf(ValidationError);
    expect(error.fieldErrors).toEqual({ [field]: [code] });
    expect(taskRepository.insertTaskTemplate).not.toHaveBeenCalled();
    expect(routineRepository.insertRoutine).not.toHaveBeenCalled();
  });

  it('CA-03 rejects a Kids session without persisting anything', async () => {
    const error = await useCase
      .execute(validCommand({ actor: { ...TEST_ACTOR, role: MemberRole.KIDS } }))
      .catch((e) => e);

    expect(error).toBeInstanceOf(ActionNotAllowedError);
    expect(transactionRunner.forFamily).not.toHaveBeenCalled();
    expect(taskRepository.insertTaskTemplate).not.toHaveBeenCalled();
  });

  it('rejects an assignee outside the family, without persisting', async () => {
    taskRepository.countFamilyMembers.mockResolvedValue(0);

    await expect(useCase.execute(validCommand())).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { assigneeIds: ['ASSIGNEE_NOT_IN_FAMILY'] },
    });
    expect(taskRepository.insertTaskTemplate).not.toHaveBeenCalled();
  });
});
