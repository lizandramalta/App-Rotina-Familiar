/** SCRUM-119 repro: does the member's "pending" aggregate match the member-filtered task list? */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import {
  GetFamilyOverviewUseCase,
  GetFamilyTasksUseCase,
} from '../../src/modules/tasks/application/get-family-tasks-use-cases.js';
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
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family tasks count vs. list persistence — SCRUM-119',
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
      };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, new Date('2026-10-01T12:00:00.000Z')],
      );
      for (const [memberId, role, isCreator, name] of [
        [family.memberId, 'administrator', true, 'Admin'],
        [family.otherMemberId, 'member', false, 'Outro membro'],
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
        [taskId, family.familyId, templateId, `single:${taskId}`, REFERENCE_DATE, params.status, NOW],
      );
      for (const memberId of params.assigneeIds) {
        await container.dbPool.query(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [family.familyId, taskId, memberId],
        );
      }
      return taskId;
    }

    function adminActorOf(family: SeededFamily): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.memberId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      };
    }

    function memberActorOf(family: SeededFamily): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.otherMemberId,
        role: MemberRole.MEMBER,
        isFamilyCreator: false,
      };
    }

    it('filtering by a member: the header pending count matches the number of pending rows listed, including a shared task', async () => {
      const family = await seedFamily();
      const exclusivePending = await seedTask(family, {
        status: 'pending',
        assigneeIds: [family.memberId],
      });
      const sharedPending = await seedTask(family, {
        status: 'pending',
        assigneeIds: [family.memberId, family.otherMemberId],
      });
      // Noise: a pending task that does NOT involve the filtered member, and a completed one that does.
      await seedTask(family, { status: 'pending', assigneeIds: [family.otherMemberId] });
      await seedTask(family, { status: 'completed', assigneeIds: [family.memberId] });

      const dependencies = { repository, transactionRunner: container.transactionRunner, clock };
      const actor = adminActorOf(family);

      const overview = await new GetFamilyOverviewUseCase(dependencies).execute(
        actor,
        REFERENCE_DATE,
        REFERENCE_DATE,
      );
      const page = await new GetFamilyTasksUseCase(dependencies).execute(actor, {
        startDate: REFERENCE_DATE,
        endDate: REFERENCE_DATE,
        memberId: family.memberId,
      });

      const memberProgress = overview.members.find((m) => m.memberId === family.memberId);
      expect(memberProgress).toBeDefined();

      const pendingRows = page.items.filter((item) => item.displayStatus === 'pending');

      expect(pendingRows.map((item) => item.id).sort()).toEqual(
        [exclusivePending, sharedPending].sort(),
      );
      expect(memberProgress?.pending).toBe(pendingRows.length);
    });

    it('a Member filtering themselves: awaitingConfirmation merges into "pending" consistently between the header and the list', async () => {
      const family = await seedFamily();
      const exclusivePending = await seedTask(family, {
        status: 'pending',
        assigneeIds: [family.otherMemberId],
      });
      const sharedAwaiting = await seedTask(family, {
        status: 'awaitingConfirmation',
        assigneeIds: [family.otherMemberId, family.memberId],
      });

      const dependencies = { repository, transactionRunner: container.transactionRunner, clock };
      const actor = memberActorOf(family);

      const overview = await new GetFamilyOverviewUseCase(dependencies).execute(
        actor,
        REFERENCE_DATE,
        REFERENCE_DATE,
      );
      const page = await new GetFamilyTasksUseCase(dependencies).execute(actor, {
        startDate: REFERENCE_DATE,
        endDate: REFERENCE_DATE,
        memberId: family.otherMemberId,
      });

      const memberProgress = overview.members.find((m) => m.memberId === family.otherMemberId);
      expect(memberProgress).toBeDefined();

      const pendingRows = page.items.filter((item) => item.displayStatus === 'pending');

      expect(pendingRows.map((item) => item.id).sort()).toEqual(
        [exclusivePending, sharedAwaiting].sort(),
      );
      expect(memberProgress?.pending).toBe(pendingRows.length);
    });
  },
);
