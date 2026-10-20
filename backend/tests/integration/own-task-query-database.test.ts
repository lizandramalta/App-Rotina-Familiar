/** Persistência da consulta pessoal diária — SPEC-009 Fase 1 / SCRUM-38. */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import {
  GetOwnProgressUseCase,
  GetOwnTasksUseCase,
} from '../../src/modules/tasks/application/get-own-tasks-use-cases.js';
import { PostgresTaskRepository } from '../../src/modules/tasks/infrastructure/postgres-task-repository.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');
const REFERENCE_DATE = '2026-10-09';

interface SeededFamily {
  readonly familyId: string;
  readonly memberId: string;
  readonly otherMemberId: string;
  readonly kidsMemberId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Own daily task query persistence',
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
          await container.dbPool.query('delete from app.task_assignees where family_id = $1', [
            family.familyId,
          ]);
          await container.dbPool.query('delete from app.task_occurrences where family_id = $1', [
            family.familyId,
          ]);
          await container.dbPool.query('delete from app.task_templates where family_id = $1', [
            family.familyId,
          ]);
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
      }
      await container?.dispose();
    });

    async function seedFamily(): Promise<SeededFamily> {
      const family: SeededFamily = {
        familyId: randomUUID(),
        memberId: randomUUID(),
        otherMemberId: randomUUID(),
        kidsMemberId: randomUUID(),
      };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, new Date('2026-10-01T12:00:00.000Z')],
      );
      for (const [memberId, role, isCreator, name] of [
        [family.memberId, 'administrator', true, 'Admin'],
        [family.otherMemberId, 'member', false, 'Outro membro'],
        [family.kidsMemberId, 'kids', false, 'Kids'],
      ] as const) {
        await container.dbPool.query(
          `insert into app.members
             (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, $3, $4, $5, $6, $6)`,
          [memberId, family.familyId, role, isCreator, name, NOW],
        );
      }
      seededFamilies.push(family);
      return family;
    }

    async function seedTask(
      family: SeededFamily,
      params: {
        readonly status: 'pending' | 'awaitingConfirmation' | 'completed';
        readonly assigneeIds: readonly string[];
      },
    ): Promise<string> {
      const templateId = randomUUID();
      const taskId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Tarefa de teste', 1, $3, $3)`,
        [templateId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
           (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
            title, weight, status, created_at, updated_at)
         values ($1, $2, $3, $4, $5, $5, 'Tarefa de teste', 1, $6, $7, $7)`,
        [
          taskId,
          family.familyId,
          templateId,
          `single:${taskId}`,
          REFERENCE_DATE,
          params.status,
          NOW,
        ],
      );
      for (const memberId of params.assigneeIds) {
        await container.dbPool.query(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [family.familyId, taskId, memberId],
        );
      }
      return taskId;
    }

    function actorOf(family: SeededFamily): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.memberId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      };
    }

    it('returns only the actor tasks and aggregates only that member progress', async () => {
      const family = await seedFamily();
      const ownPending = await seedTask(family, {
        status: 'pending',
        assigneeIds: [family.memberId],
      });
      const ownCompleted = await seedTask(family, {
        status: 'completed',
        assigneeIds: [family.memberId, family.otherMemberId],
      });
      await seedTask(family, { status: 'pending', assigneeIds: [family.otherMemberId] });

      const foreignFamily = await seedFamily();
      await seedTask(foreignFamily, { status: 'completed', assigneeIds: [foreignFamily.memberId] });

      const dependencies = { repository, transactionRunner: container.transactionRunner, clock };
      const tasks = await new GetOwnTasksUseCase(dependencies).execute(
        actorOf(family),
        REFERENCE_DATE,
        undefined,
      );
      const progress = await new GetOwnProgressUseCase(dependencies).execute(
        actorOf(family),
        REFERENCE_DATE,
      );

      expect(tasks.items.map((task) => task.id).sort()).toEqual([ownPending, ownCompleted].sort());
      expect(progress).toEqual({ total: 2, completed: 1, percentage: 50 });
    });

    it('SCRUM-107 / SPEC-009 CA-01, CA-04, CA-08 and CA-11 projects per actor and preserves own progress and family isolation', async () => {
      const family = await seedFamily();
      const shared = await seedTask(family, {
        status: 'awaitingConfirmation',
        assigneeIds: [family.memberId, family.kidsMemberId],
      });
      const adultOnly = await seedTask(family, {
        status: 'completed',
        assigneeIds: [family.memberId],
      });
      await seedTask(family, { status: 'pending', assigneeIds: [family.otherMemberId] });
      await seedTask(family, { status: 'pending', assigneeIds: [] });

      const foreignFamily = await seedFamily();
      await seedTask(foreignFamily, {
        status: 'completed',
        assigneeIds: [foreignFamily.memberId],
      });

      const dependencies = { repository, transactionRunner: container.transactionRunner, clock };
      const getTasks = new GetOwnTasksUseCase(dependencies);
      const adult = actorOf(family);
      const kids = {
        ...adult,
        memberId: family.kidsMemberId,
        role: MemberRole.KIDS,
        isFamilyCreator: false,
      };
      const otherAdult = {
        ...adult,
        memberId: family.otherMemberId,
        role: MemberRole.MEMBER,
        isFamilyCreator: false,
      };

      const adultTasks = await getTasks.execute(adult, REFERENCE_DATE, undefined);
      const kidsTasks = await getTasks.execute(kids, REFERENCE_DATE, undefined);
      const otherAdultTasks = await getTasks.execute(otherAdult, REFERENCE_DATE, undefined);
      const progress = await new GetOwnProgressUseCase(dependencies).execute(adult, REFERENCE_DATE);

      expect(adultTasks.items.map((task) => task.id).sort()).toEqual([shared, adultOnly].sort());
      expect(adultTasks.items.find((task) => task.id === shared)).toMatchObject({
        status: 'awaitingConfirmation',
        displayStatus: 'pending',
      });
      expect(adultTasks.items.find((task) => task.id === adultOnly)).toMatchObject({
        status: 'completed',
        displayStatus: 'completed',
      });
      expect(kidsTasks.items).toEqual([
        expect.objectContaining({
          id: shared,
          status: 'awaitingConfirmation',
          displayStatus: 'awaitingConfirmation',
        }),
      ]);
      expect(otherAdultTasks.items).toHaveLength(1);
      expect(progress).toEqual({ total: 2, completed: 1, percentage: 50 });
    });
  },
);
