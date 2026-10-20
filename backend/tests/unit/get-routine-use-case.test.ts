/** Caso de uso `GetRoutine` (SPEC-008 Fase 1 / SCRUM-43): CA-03 a CA-05. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { GetRoutineUseCase } from '../../src/modules/routines/application/get-routine-use-case.js';
import { MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH } from '../../src/modules/routines/application/routine-repository-port.js';
import type {
  RoutineRecord,
  RoutineRepositoryPort,
} from '../../src/modules/routines/application/routine-repository-port.js';
import type { FamilySettingsRepositoryPort } from '../../src/modules/family/application/family-settings-repository-port.js';
import { ActionNotAllowedError, NotFoundError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T12:00:00.000Z');
const ROUTINE_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';

const ROUTINE: RoutineRecord = {
  id: ROUTINE_ID,
  familyId: TEST_ACTOR.familyId,
  taskTemplateId: 'e4f5a6b7-c8d9-0123-4567-89abcdef0123',
  title: 'Separar recicláveis',
  weight: 2,
  note: null,
  assigneeIds: [TEST_ACTOR.memberId],
  frequencyDays: 7,
  startDate: '2026-10-10',
  isActive: true,
  generatedUntil: null,
  createdAt: NOW,
};

describe('GetRoutineUseCase — SPEC-008', () => {
  let routineRepository: Record<keyof RoutineRepositoryPort, ReturnType<typeof vi.fn>>;
  let familySettingsRepository: { findFamilyTimeZone: ReturnType<typeof vi.fn> };
  let transactionRunner: TransactionRunner;
  let useCase: GetRoutineUseCase;

  beforeEach(() => {
    routineRepository = {
      insertRoutine: vi.fn(),
      findRoutine: vi.fn().mockResolvedValue(ROUTINE),
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

    useCase = new GetRoutineUseCase({
      routineRepository: routineRepository as unknown as RoutineRepositoryPort,
      familySettingsRepository: familySettingsRepository as unknown as FamilySettingsRepositoryPort,
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
  });

  it('CA-01 returns the canonical configuration, locking the routine under the family lock', async () => {
    const result = await useCase.execute(TEST_ACTOR, ROUTINE_ID);

    expect(transactionRunner.forFamily).toHaveBeenCalledWith(
      TEST_ACTOR.familyId,
      expect.any(Function),
    );
    expect(routineRepository.findRoutine).toHaveBeenCalledWith(
      expect.anything(),
      TEST_ACTOR.familyId,
      ROUTINE_ID,
      true,
    );
    expect(result).toMatchObject({
      id: ROUTINE_ID,
      title: 'Separar recicláveis',
      weight: 2,
      frequencyDays: 7,
      startDate: '2026-10-10',
      isActive: true,
    });
  });

  it('CA-05 completes one more batch when generatedUntil has not reached the current horizon', async () => {
    routineRepository.findRoutine.mockResolvedValue({ ...ROUTINE, generatedUntil: '2026-10-24' });
    routineRepository.materializeBatch.mockResolvedValue({
      generatedUntil: '2026-11-30',
      isComplete: true,
    });

    const result = await useCase.execute(TEST_ACTOR, ROUTINE_ID);

    expect(routineRepository.materializeBatch).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        horizon: '2026-11-30',
        maxBatch: MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
      }),
    );
    expect(result.materializationState).toBe('complete');
  });

  it('CA-05 does not call materializeBatch again once generatedUntil already reached the horizon', async () => {
    routineRepository.findRoutine.mockResolvedValue({ ...ROUTINE, generatedUntil: '2026-11-30' });

    const result = await useCase.execute(TEST_ACTOR, ROUTINE_ID);

    expect(routineRepository.materializeBatch).not.toHaveBeenCalled();
    expect(result.materializationState).toBe('complete');
  });

  it('CA-05 reports pending while generatedUntil still trails the horizon after a batch', async () => {
    routineRepository.materializeBatch.mockResolvedValue({
      generatedUntil: '2026-10-24',
      isComplete: false,
    });

    const result = await useCase.execute(TEST_ACTOR, ROUTINE_ID);

    expect(result.materializationState).toBe('pending');
  });

  it('CA-03 rejects a Kids session without touching the repository', async () => {
    const error = await useCase
      .execute({ ...TEST_ACTOR, role: MemberRole.KIDS }, ROUTINE_ID)
      .catch((e) => e);

    expect(error).toBeInstanceOf(ActionNotAllowedError);
    expect(transactionRunner.forFamily).not.toHaveBeenCalled();
  });

  it('CA-04 responds 404 for a routine from another family or nonexistent', async () => {
    routineRepository.findRoutine.mockResolvedValue(undefined);

    const error = await useCase.execute(TEST_ACTOR, ROUTINE_ID).catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
    expect(routineRepository.materializeBatch).not.toHaveBeenCalled();
  });
});
