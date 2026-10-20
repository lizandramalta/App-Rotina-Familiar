import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  GetOwnProgressUseCase,
  GetOwnTasksUseCase,
} from '../../src/modules/tasks/application/get-own-tasks-use-cases.js';
import type { TaskQueryRepositoryPort } from '../../src/modules/tasks/application/task-query-repository-port.js';
import type { TaskRecord } from '../../src/modules/tasks/application/task-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');
const CALENDAR = {
  createdAt: new Date('2026-10-01T15:00:00.000Z'),
  timeZoneId: 'America/Sao_Paulo',
};
const TASK: TaskRecord = {
  id: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e',
  familyId: TEST_ACTOR.familyId,
  title: 'Arrumar os brinquedos',
  weight: 2,
  scheduledDate: '2026-10-09',
  note: null,
  status: 'pending',
  routineId: null,
  createdAt: NOW,
  assigneeIds: [TEST_ACTOR.memberId],
};

describe('Own daily task queries — SPEC-009 phase 1 / SCRUM-38', () => {
  let repository: Record<keyof TaskQueryRepositoryPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;

  beforeEach(() => {
    repository = {
      findFamilyCalendar: vi.fn().mockResolvedValue(CALENDAR),
      findOwnTasksPage: vi.fn().mockResolvedValue([TASK]),
      countOwnTasksProgress: vi.fn().mockResolvedValue({ total: 1, completed: 0 }),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(),
    } as unknown as TransactionRunner;
  });

  const dependencies = () => ({
    repository: repository as unknown as TaskQueryRepositoryPort,
    transactionRunner,
    clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
  });

  it('CA-01 and CA-04 query only the Kids actor member for the selected day', async () => {
    const kidsActor = { ...TEST_ACTOR, role: MemberRole.KIDS };

    const result = await new GetOwnTasksUseCase(dependencies()).execute(
      kidsActor,
      '2026-10-09',
      undefined,
    );

    expect(result).toEqual({ items: [expect.objectContaining({ id: TASK.id })], nextCursor: null });
    expect(repository.findOwnTasksPage).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        memberId: TEST_ACTOR.memberId,
        referenceDate: '2026-10-09',
        after: undefined,
      }),
    );
  });

  it.each([
    [MemberRole.ADMINISTRATOR, 'pending'],
    [MemberRole.MEMBER, 'pending'],
    [MemberRole.KIDS, 'awaitingConfirmation'],
  ] as const)(
    'SCRUM-107 / SPEC-009 CA-11 projects awaiting confirmation for %s without changing the canonical status',
    async (role, displayStatus) => {
      repository.findOwnTasksPage.mockResolvedValue([
        { ...TASK, status: 'awaitingConfirmation' },
        { ...TASK, id: '79b5ebaf-b271-47be-a267-3dc9e06483aa', status: 'pending' },
        { ...TASK, id: '62d8bd51-b512-47fa-81fa-10e664a79e36', status: 'completed' },
      ]);

      const result = await new GetOwnTasksUseCase(dependencies()).execute(
        { ...TEST_ACTOR, role },
        '2026-10-09',
        undefined,
      );

      expect(result.items.map(({ status, displayStatus: shown }) => [status, shown])).toEqual([
        ['awaitingConfirmation', displayStatus],
        ['pending', 'pending'],
        ['completed', 'completed'],
      ]);
    },
  );

  it('CA-02 binds a pagination cursor to the selected personal day', async () => {
    repository.findOwnTasksPage.mockResolvedValue([
      ...Array.from({ length: 20 }, () => TASK),
      TASK,
    ]);
    const useCase = new GetOwnTasksUseCase(dependencies());
    const page = await useCase.execute(TEST_ACTOR, '2026-10-09', undefined);

    await expect(useCase.execute(TEST_ACTOR, '2026-10-08', page.nextCursor)).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { cursor: ['CURSOR_INVALID'] },
    });
  });

  it.each(['not-a-date', '2026-09-30', '2026-11-01'])(
    'CA-03 rejects an invalid or unavailable reference date: %s',
    async (referenceDate) => {
      await expect(
        new GetOwnTasksUseCase(dependencies()).execute(TEST_ACTOR, referenceDate, undefined),
      ).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
        fieldErrors: { referenceDate: expect.any(Array) },
      });
      expect(repository.findOwnTasksPage).not.toHaveBeenCalled();
    },
  );

  it('CA-03 returns null percentage for a confirmed empty personal day', async () => {
    repository.countOwnTasksProgress.mockResolvedValue({ total: 0, completed: 0 });

    await expect(
      new GetOwnProgressUseCase(dependencies()).execute(TEST_ACTOR, '2026-10-09'),
    ).resolves.toEqual({ total: 0, completed: 0, percentage: null });
  });

  it('CA-08 translates an unavailable query dependency without pretending an empty result', async () => {
    repository.countOwnTasksProgress.mockRejectedValue(new Error('database unavailable'));

    await expect(
      new GetOwnProgressUseCase(dependencies()).execute(TEST_ACTOR, '2026-10-09'),
    ).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', statusCode: 503 });
  });
});
