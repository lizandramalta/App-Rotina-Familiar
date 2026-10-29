/** Family section persistence: SPEC-009 CA-06–12, SPEC-012 CA-01–06,
 * SPEC-013 CA-01–06 and SPEC-019 CA-01–04. */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import {
  GetFamilyOverviewUseCase,
  GetFamilyTasksUseCase,
} from '../../src/modules/tasks/application/get-family-tasks-use-cases.js';
import { PostgresTaskRepository } from '../../src/modules/tasks/infrastructure/postgres-task-repository.js';
import { GetWeeklyReportSnapshotUseCase } from '../../src/modules/reports/application/get-weekly-report-snapshot-use-case.js';
import { PostgresWeeklyReportRepository } from '../../src/modules/reports/infrastructure/postgres-weekly-report-repository.js';
import {
  SignalTaskUseCase,
  ListKidsSignalsUseCase,
  DecideKidsSignalUseCase,
} from '../../src/modules/kids/application/kids-signal-use-cases.js';
import { PostgresKidsSignalRepository } from '../../src/modules/kids/infrastructure/postgres-kids-signal-repository.js';
import { RemoveMemberUseCase } from '../../src/modules/family/application/member-management-use-cases.js';
import { PostgresMemberManagementRepository } from '../../src/modules/family/infrastructure/postgres-member-management-repository.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');
const clock: Clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family section persistence',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const taskRepository = new PostgresTaskRepository();
    const signalRepository = new PostgresKidsSignalRepository();
    const familyIds: string[] = [];

    beforeAll(() => {
      container = createContainer(loadConfiguration());
    });
    afterAll(async () => {
      if (container) {
        for (const familyId of familyIds) {
          for (const table of [
            'completion_credits',
            'completions',
            'task_events',
            'kids_signals',
            'mission_tasks',
            'task_assignees',
            'task_occurrences',
            'task_templates',
          ]) {
            await container.dbPool.query(`delete from app.${table} where family_id = $1`, [
              familyId,
            ]);
          }
          await container.dbPool.query('delete from app.families where id = $1', [familyId]);
        }
        await container.dispose();
      }
    });

    async function seed() {
      const familyId = randomUUID();
      const adminId = randomUUID();
      const memberId = randomUUID();
      const kidId = randomUUID();
      const taskId = randomUUID();
      const templateId = randomUUID();
      familyIds.push(familyId);
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at)
       values ($1, 'Casa de teste', 'America/Sao_Paulo', '2026-10-01T12:00:00Z')`,
        [familyId],
      );
      for (const [id, role, creator, name] of [
        [adminId, 'administrator', true, 'Admin'],
        [memberId, 'member', false, 'Membro'],
        [kidId, 'kids', false, 'Kids'],
      ] as const) {
        await container.dbPool.query(
          `insert into app.members (id, family_id, role, is_family_creator, display_name)
         values ($1, $2, $3, $4, $5)`,
          [id, familyId, role, creator, name],
        );
      }
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
       values ($1, $2, 'Arrumar', 2, $3, $3)`,
        [templateId, familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
       (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
        title, weight, status, created_at, updated_at)
       values ($1, $2, $3, $4, '2026-10-09', '2026-10-09', 'Arrumar', 2, 'pending', $5, $5)`,
        [taskId, familyId, templateId, `single:${taskId}`, NOW],
      );
      for (const id of [memberId, kidId]) {
        await container.dbPool.query(
          'insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)',
          [familyId, taskId, id],
        );
      }
      const actor = (id: string, role: MemberRole): ActorContext => ({
        sessionId: randomUUID(),
        familyId,
        memberId: id,
        role,
        isFamilyCreator: id === adminId,
      });
      return {
        familyId,
        admin: actor(adminId, MemberRole.ADMINISTRATOR),
        member: actor(memberId, MemberRole.MEMBER),
        kid: actor(kidId, MemberRole.KIDS),
        taskId,
      };
    }

    it('projects a free date range by role, confirms Kids once and produces a weekly credit snapshot', async () => {
      const family = await seed();
      const queryDeps = {
        repository: taskRepository,
        transactionRunner: container.transactionRunner,
        clock,
      };
      const overview = new GetFamilyOverviewUseCase(queryDeps);
      const tasks = new GetFamilyTasksUseCase(queryDeps);
      const signalDeps = {
        signals: signalRepository,
        tasks: taskRepository,
        transactionRunner: container.transactionRunner,
        clock,
        missionCloser: {
          closeForCompletedTask: async () => undefined,
          closeAfterTaskDeletion: async () => undefined,
        },
      };
      const range = { startDate: '2026-10-07', endDate: '2026-10-10' };
      expect(
        (await overview.execute(family.admin, range.startDate, range.endDate)).progress.total,
      ).toBe(1);
      const signal = await new SignalTaskUseCase(signalDeps).execute(
        family.kid,
        family.taskId,
        undefined,
      );
      const adminOverview = await overview.execute(family.admin, range.startDate, range.endDate);
      const memberOverview = await overview.execute(family.member, range.startDate, range.endDate);
      expect(adminOverview.progress.awaitingConfirmation).toBe(1);
      expect(memberOverview.progress.pending).toBe(1);
      expect(memberOverview.progress.awaitingConfirmation).toBe(0);
      const memberTasks = await tasks.execute(family.member, { ...range, status: 'pending' });
      expect(memberTasks.items[0]).toMatchObject({
        id: family.taskId,
        status: 'awaitingConfirmation',
        displayStatus: 'pending',
        completedAt: null,
      });
      const queue = await new ListKidsSignalsUseCase(signalDeps).execute(family.admin);
      expect(queue.items[0]?.signalId).toBe(signal.signal.id);
      const decision = new DecideKidsSignalUseCase(signalDeps);
      expect((await decision.execute(family.admin, signal.signal.id, 'confirm')).applied).toBe(
        true,
      );
      expect((await decision.execute(family.admin, signal.signal.id, 'confirm')).applied).toBe(
        false,
      );
      const completedMemberTasks = await tasks.execute(family.member, {
        ...range, memberId: family.member.memberId, status: 'completed',
      });
      expect(completedMemberTasks.items[0]?.completedAt).toBe(NOW.toISOString());
      expect(
        (await new ListKidsSignalsUseCase(signalDeps).execute(family.admin)).items,
      ).toHaveLength(0);
      const report = await new GetWeeklyReportSnapshotUseCase({
        repository: new PostgresWeeklyReportRepository(),
        transactionRunner: container.transactionRunner,
        clock,
      }).execute(family.member, '2026-10-09');
      expect(report.progress).toMatchObject({ total: 1, completed: 1 });
      expect(report.load.totalWeight).toBe(4);
      expect(report.members.filter((item) => item.weight === 2)).toHaveLength(2);
    });

    it('logically removes a member and releases only future unprotected assignments (SPEC-003 CA-06)', async () => {
      const family = await seed();
      const futureTaskId = randomUUID();
      const templateId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
       values ($1, $2, 'Futuro', 1, $3, $3)`,
        [templateId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
       (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
        title, weight, status, created_at, updated_at)
       values ($1, $2, $3, $4, '2026-10-12', '2026-10-12', 'Futuro', 1, 'pending', $5, $5)`,
        [futureTaskId, family.familyId, templateId, `single:${futureTaskId}`, NOW],
      );
      await container.dbPool.query(
        'insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)',
        [family.familyId, futureTaskId, family.kid.memberId],
      );
      await new RemoveMemberUseCase({
        repository: new PostgresMemberManagementRepository(),
        transactionRunner: container.transactionRunner,
        clock,
      }).execute(family.admin, family.kid.memberId);
      const removed = await container.dbPool.query(
        'select removed_at from app.members where family_id = $1 and id = $2',
        [family.familyId, family.kid.memberId],
      );
      expect(removed.rows[0]?.removed_at).toEqual(NOW);
      const assignments = await container.dbPool.query(
        'select task_id from app.task_assignees where family_id = $1 and member_id = $2',
        [family.familyId, family.kid.memberId],
      );
      expect(assignments.rows).toEqual([{ task_id: family.taskId }]);
    });
  },
);
