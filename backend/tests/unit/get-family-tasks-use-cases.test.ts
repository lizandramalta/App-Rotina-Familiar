import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  GetFamilyOverviewUseCase,
  GetFamilyTasksUseCase,
} from '../../src/modules/tasks/application/get-family-tasks-use-cases.js';
import type { TaskQueryRepositoryPort } from '../../src/modules/tasks/application/task-query-repository-port.js';
import type { TaskRecord } from '../../src/modules/tasks/application/task-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const TASK: TaskRecord = {
  id: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e',
  familyId: TEST_ACTOR.familyId,
  title: 'Arrumar os brinquedos',
  weight: 2,
  scheduledDate: '2026-10-09',
  note: null,
  status: 'awaitingConfirmation',
  routineId: null,
  createdAt: new Date('2026-10-08T12:00:00Z'),
  assigneeIds: [TEST_ACTOR.memberId],
};

describe('Family range queries — SPEC-009 CA-05 to CA-10 and CA-12', () => {
  let repository: Record<keyof TaskQueryRepositoryPort, ReturnType<typeof vi.fn>>;
  let overview: GetFamilyOverviewUseCase;
  let tasks: GetFamilyTasksUseCase;

  beforeEach(() => {
    repository = {
      findFamilyCalendar: vi.fn().mockResolvedValue({
        createdAt: new Date('2026-10-01T12:00:00Z'),
        timeZoneId: 'America/Sao_Paulo',
      }),
      findOwnTasksPage: vi.fn(),
      countOwnTasksProgress: vi.fn(),
      findFamilyOverview: vi.fn().mockResolvedValue({
        family: { total: 25, completed: 17, pending: 6, awaitingConfirmation: 2 },
        members: [
          {
            memberId: TEST_ACTOR.memberId,
            name: 'Alex',
            role: 'member',
            total: 25,
            completed: 17,
            pending: 6,
            awaitingConfirmation: 2,
          },
        ],
      }),
      findFamilyTasksPage: vi.fn().mockResolvedValue([TASK]),
      familyMemberExists: vi.fn().mockResolvedValue(true),
    };
    const runner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(),
    } as unknown as TransactionRunner;
    const deps = {
      repository: repository as unknown as TaskQueryRepositoryPort,
      transactionRunner: runner,
      clock: {
        now: () => new Date('2026-10-27T12:00:00Z'),
        nowIsoString: () => '2026-10-27T12:00:00.000Z',
      },
    };
    overview = new GetFamilyOverviewUseCase(deps);
    tasks = new GetFamilyTasksUseCase(deps);
  });

  it('projects awaiting confirmation into Pending for a Member without changing task status', async () => {
    const member = { ...TEST_ACTOR, role: MemberRole.MEMBER };
    const progress = await overview.execute(member, '2026-10-01', '2026-10-27');
    expect(progress.progress).toMatchObject({
      total: 25,
      completed: 17,
      pending: 8,
      awaitingConfirmation: 0,
    });
    const page = await tasks.execute(member, {
      startDate: '2026-10-01',
      endDate: '2026-10-27',
      status: 'pending',
    });
    expect(repository.findFamilyTasksPage).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ statuses: ['pending', 'awaitingConfirmation'] }),
    );
    expect(page.items[0]).toMatchObject({
      status: 'awaitingConfirmation',
      displayStatus: 'pending',
    });
  });

  it('keeps awaiting confirmation separate for an Administrator', async () => {
    const progress = await overview.execute(TEST_ACTOR, '2026-10-01', '2026-10-27');
    expect(progress.progress).toMatchObject({ pending: 6, awaitingConfirmation: 2 });
    const page = await tasks.execute(TEST_ACTOR, {
      startDate: '2026-10-01',
      endDate: '2026-10-27',
      status: 'awaitingConfirmation',
    });
    expect(page.items[0]?.displayStatus).toBe('awaitingConfirmation');
  });

  it('rejects reversed or out-of-range dates and hides family data from Kids', async () => {
    await expect(overview.execute(TEST_ACTOR, '2026-10-20', '2026-10-01')).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
    });
    await expect(overview.execute(TEST_ACTOR, '2026-09-30', '2026-10-01')).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
    });
    await expect(
      overview.execute({ ...TEST_ACTOR, role: MemberRole.KIDS }, '2026-10-01', '2026-10-27'),
    ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
  });

  it('does not expose a member from another family', async () => {
    repository.familyMemberExists.mockResolvedValue(false);
    await expect(
      tasks.execute(TEST_ACTOR, {
        startDate: '2026-10-01',
        endDate: '2026-10-27',
        memberId: '1ebc9f9b-0694-41e8-b2c1-837e39e49611',
      }),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
  });
});
