/**
 * Persistência crítica de conclusão (SPEC-010 Fase 1 / SCRUM-40).
 *
 * PostgreSQL real comprova o que dublês não alcançam: lock familiar,
 * unicidade de conclusão/crédito, isolamento e preservação da evidência Kids.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { CompleteTaskUseCase } from '../../src/modules/tasks/application/manage-task-use-cases.js';
import { PostgresTaskRepository } from '../../src/modules/tasks/infrastructure/postgres-task-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly adminId: string;
  readonly memberId: string;
  readonly kidId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Task completion persistence',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const repository = new PostgresTaskRepository();
    const seededFamilies: SeededFamily[] = [];
    const clock: Clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of seededFamilies) {
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
              family.familyId,
            ]);
          }
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
      }
      await container?.dispose();
    });

    const completeTask = () =>
      new CompleteTaskUseCase({
        repository,
        transactionRunner: container.transactionRunner,
        clock,
        missionCloser: {
          closeForCompletedTask: async () => undefined,
          closeAfterTaskDeletion: async () => undefined,
        },
      });

    async function seedFamily(): Promise<SeededFamily> {
      const family = {
        familyId: randomUUID(),
        adminId: randomUUID(),
        memberId: randomUUID(),
        kidId: randomUUID(),
      };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, NOW],
      );
      for (const [id, role, creator] of [
        [family.adminId, 'administrator', true],
        [family.memberId, 'member', false],
        [family.kidId, 'kids', false],
      ] as const) {
        await container.dbPool.query(
          `insert into app.members
            (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, $3, $4, 'Pessoa de teste', $5, $5)`,
          [id, family.familyId, role, creator, NOW],
        );
      }
      seededFamilies.push(family);
      return family;
    }

    async function seedTask(
      family: SeededFamily,
      assigneeIds: readonly string[],
      status: 'pending' | 'awaitingConfirmation' = 'pending',
    ): Promise<string> {
      const taskTemplateId = randomUUID();
      const taskId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Tarefa de teste', 2, $3, $3)`,
        [taskTemplateId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
          (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
           title, weight, status, created_at, updated_at)
         values ($1, $2, $3, $4, '2026-10-09', '2026-10-09', 'Tarefa de teste', 2, $5, $6, $6)`,
        [taskId, family.familyId, taskTemplateId, `single:${taskId}`, status, NOW],
      );
      for (const memberId of assigneeIds) {
        await container.dbPool.query(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [family.familyId, taskId, memberId],
        );
      }
      return taskId;
    }

    function actor(
      family: SeededFamily,
      memberId: string,
      role: ActorContext['role'],
    ): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId,
        role,
        isFamilyCreator: role === MemberRole.ADMINISTRATOR,
      };
    }

    it('CA-02 assigns an unassigned task only on confirmed completion and records one credit', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, []);

      const result = await completeTask().execute(
        actor(family, family.adminId, MemberRole.ADMINISTRATOR),
        taskId,
      );

      expect(result.task).toMatchObject({
        id: taskId,
        status: 'completed',
        assigneeIds: [family.adminId],
      });
      expect(
        await container.dbPool.query(
          `select performed_by_id, completed_at from app.completions where family_id = $1 and task_id = $2`,
          [family.familyId, taskId],
        ),
      ).toMatchObject({
        rowCount: 1,
        rows: [{ performed_by_id: family.adminId, completed_at: NOW }],
      });
      expect(
        await container.dbPool.query(
          `select member_id, weight from app.completion_credits where family_id = $1`,
          [family.familyId],
        ),
      ).toMatchObject({ rowCount: 1, rows: [{ member_id: family.adminId, weight: 2 }] });
    });

    it('CA-04/CA-05 preserves the pending Kids evidence and permits only an Administrator', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, [family.kidId], 'awaitingConfirmation');
      await container.dbPool.query(
        `insert into app.kids_signals (id, family_id, task_id, signaled_by_id, created_at)
         values ($1, $2, $3, $4, $5)`,
        [randomUUID(), family.familyId, taskId, family.kidId, NOW],
      );

      await expect(
        completeTask().execute(actor(family, family.memberId, MemberRole.MEMBER), taskId),
      ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
      expect(
        (
          await container.dbPool.query(
            `select status from app.task_occurrences where family_id = $1 and id = $2`,
            [family.familyId, taskId],
          )
        ).rows,
      ).toEqual([{ status: 'awaitingConfirmation' }]);

      await completeTask().execute(actor(family, family.adminId, MemberRole.ADMINISTRATOR), taskId);
      expect(
        (
          await container.dbPool.query(
            `select status from app.task_occurrences where family_id = $1 and id = $2`,
            [family.familyId, taskId],
          )
        ).rows,
      ).toEqual([{ status: 'completed' }]);
      expect(
        (
          await container.dbPool.query(
            `select discarded_at from app.kids_signals where family_id = $1 and task_id = $2`,
            [family.familyId, taskId],
          )
        ).rows,
      ).toEqual([{ discarded_at: null }]);
    });

    it('CA-06/CA-07 serializes competing completion and hides a foreign task', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, [family.memberId]);
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      const results = await Promise.allSettled([
        completeTask().execute(admin, taskId),
        completeTask().execute(admin, taskId),
      ]);

      expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
      expect(results.find((result) => result.status === 'rejected')).toMatchObject({
        status: 'rejected',
        reason: { code: 'TASK_ALREADY_COMPLETED' },
      });
      expect(
        (
          await container.dbPool.query(
            `select id from app.completions where family_id = $1 and task_id = $2`,
            [family.familyId, taskId],
          )
        ).rowCount,
      ).toBe(1);

      const foreign = await seedFamily();
      await expect(
        completeTask().execute(actor(foreign, foreign.adminId, MemberRole.ADMINISTRATOR), taskId),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    });
  },
);
