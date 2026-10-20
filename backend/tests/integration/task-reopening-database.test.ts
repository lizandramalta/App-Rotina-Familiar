/** SCRUM-56 / SPEC-011 phase 1: transaction, family isolation and concurrent reopening. */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';

interface FamilyFixture {
  familyId: string;
  adminId: string;
  memberId: string;
  kidId: string;
}

const NOW = new Date('2026-10-09T12:00:00.000Z');

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'SCRUM-56 / SPEC-011 task reopening persistence',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const families: FamilyFixture[] = [];

    beforeAll(() => {
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of families) {
          await container.dbPool.query(
            `delete from app.badge_participations
              where member_id in (select id from app.members where family_id = $1)`,
            [family.familyId],
          );
          for (const table of [
            'member_badges',
            'mission_participations',
            'mission_tasks',
            'missions',
            'completion_credits',
            'completions',
            'task_events',
            'task_assignees',
            'task_occurrences',
            'task_templates',
            'members',
          ]) {
            await container.dbPool.query(`delete from app.${table} where family_id = $1`, [
              family.familyId,
            ]);
          }
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
        await container.dispose();
      }
    });

    async function seedFamily(): Promise<FamilyFixture> {
      const family = {
        familyId: randomUUID(),
        adminId: randomUUID(),
        memberId: randomUUID(),
        kidId: randomUUID(),
      };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Test family', 'America/Sao_Paulo', $2, $2)`,
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
           values ($1, $2, $3, $4, 'Test member', $5, $5)`,
          [id, family.familyId, role, creator, NOW],
        );
      }
      families.push(family);
      return family;
    }

    async function seedTask(
      family: FamilyFixture,
      assigneeIds: readonly string[],
    ): Promise<string> {
      const templateId = randomUUID();
      const taskId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Test task', 2, $3, $3)`,
        [templateId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
          (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
           title, weight, status, created_at, updated_at)
         values ($1, $2, $3, $4, '2026-10-09', '2026-10-09', 'Test task', 2,
                 'pending', $5, $5)`,
        [taskId, family.familyId, templateId, `single:${taskId}`, NOW],
      );
      for (const memberId of assigneeIds) {
        await container.dbPool.query(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [family.familyId, taskId, memberId],
        );
      }
      return taskId;
    }

    async function seedMission(family: FamilyFixture, taskId: string): Promise<string> {
      const missionId = randomUUID();
      await container.dbPool.query(
        `insert into app.missions (id, family_id, title, created_at, updated_at)
         values ($1, $2, 'Test mission', $3, $3)`,
        [missionId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.mission_tasks (family_id, mission_id, task_id) values ($1, $2, $3)`,
        [family.familyId, missionId, taskId],
      );
      return missionId;
    }

    function actor(
      family: FamilyFixture,
      memberId: string,
      role: ActorContext['role'],
    ): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId,
        role,
        isFamilyCreator: memberId === family.adminId,
      };
    }

    it('CA-01/04/06 preserves assignees and history while removing current credits', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, [family.memberId, family.kidId]);
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      await container.completeTaskUseCase.execute(admin, taskId);

      const result = await container.reopenTaskUseCase.execute(
        actor(family, family.kidId, MemberRole.KIDS),
        taskId,
        false,
      );
      expect(result.task).toMatchObject({
        status: 'pending',
        assigneeIds: [family.memberId, family.kidId].sort(),
      });
      expect(result.affectedResources.missionsReopened).toEqual([]);
      const current = await container.dbPool.query(
        `select count(*)::integer as total from app.completions
          where family_id = $1 and task_id = $2 and undone_at is null`,
        [family.familyId, taskId],
      );
      expect(current.rows[0].total).toBe(0);
      const history = await container.dbPool.query(
        `select undone_at, undone_by_id from app.completions
          where family_id = $1 and task_id = $2`,
        [family.familyId, taskId],
      );
      expect(history.rows[0].undone_at).not.toBeNull();
      expect(history.rows[0].undone_by_id).toBe(family.kidId);
      const credits = await container.dbPool.query(
        `select count(*)::integer as total from app.completion_credits
          where family_id = $1`,
        [family.familyId],
      );
      expect(credits.rows[0].total).toBe(2);
      await expect(container.reopenTaskUseCase.execute(admin, taskId, false)).rejects.toMatchObject(
        {
          code: 'TASK_NOT_COMPLETED',
        },
      );
    });

    it('CA-02/03 reverses completed missions and a threshold badge only after confirmation', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, [family.memberId]);
      const missionIds = await Promise.all(
        Array.from({ length: 5 }, () => seedMission(family, taskId)),
      );
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      await container.completeTaskUseCase.execute(admin, taskId);
      const badgeBefore = await container.dbPool.query(
        `select badge_code from app.member_badges where family_id = $1 and member_id = $2`,
        [family.familyId, family.memberId],
      );
      expect(badgeBefore.rows.map((row) => row.badge_code)).toEqual(['bronze']);

      await expect(container.reopenTaskUseCase.execute(admin, taskId, false)).rejects.toMatchObject(
        {
          code: 'MISSION_REOPEN_REQUIRES_CONFIRMATION',
          missionsAffected: expect.arrayContaining(
            missionIds.map((id) => ({ id, title: 'Test mission' })),
          ),
        },
      );
      const stillCompleted = await container.dbPool.query(
        `select count(*)::integer as total from app.missions
          where family_id = $1 and completed_at is not null`,
        [family.familyId],
      );
      expect(stillCompleted.rows[0].total).toBe(5);

      const result = await container.reopenTaskUseCase.execute(admin, taskId, true);
      expect(result.affectedResources).toMatchObject({
        participationsRemoved: 5,
        badgesRemoved: [{ memberId: family.memberId, tier: 'bronze' }],
        rewardRemoved: false,
      });
      expect(result.affectedResources.missionsReopened).toHaveLength(5);
      const persisted = await container.dbPool.query(
        `select (select count(*) from app.mission_participations where family_id = $1)::integer as participations,
                (select count(*) from app.member_badges where family_id = $1)::integer as badges,
                (select count(*) from app.missions where family_id = $1 and completed_at is not null)::integer as completed`,
        [family.familyId],
      );
      expect(persisted.rows[0]).toEqual({ participations: 0, badges: 0, completed: 0 });
    });

    it('CA-05/07 denies Kids without assignment and conceals another family', async () => {
      const family = await seedFamily();
      const other = await seedFamily();
      const taskId = await seedTask(family, [family.memberId]);
      await container.completeTaskUseCase.execute(
        actor(family, family.adminId, MemberRole.ADMINISTRATOR),
        taskId,
      );
      await expect(
        container.reopenTaskUseCase.execute(
          actor(family, family.kidId, MemberRole.KIDS),
          taskId,
          false,
        ),
      ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
      await expect(
        container.reopenTaskUseCase.execute(
          actor(other, other.adminId, MemberRole.ADMINISTRATOR),
          taskId,
          false,
        ),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
      const task = await container.dbPool.query(
        `select status from app.task_occurrences where family_id = $1 and id = $2`,
        [family.familyId, taskId],
      );
      expect(task.rows[0].status).toBe('completed');
    });

    it('CA-03 retains a badge when five other mission participations still qualify', async () => {
      const family = await seedFamily();
      const targetTaskId = await seedTask(family, [family.memberId]);
      const otherTaskId = await seedTask(family, [family.memberId]);
      await seedMission(family, targetTaskId);
      await Promise.all(Array.from({ length: 5 }, () => seedMission(family, otherTaskId)));
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      await container.completeTaskUseCase.execute(admin, targetTaskId);
      await container.completeTaskUseCase.execute(admin, otherTaskId);

      const result = await container.reopenTaskUseCase.execute(admin, targetTaskId, true);
      expect(result.affectedResources).toMatchObject({
        participationsRemoved: 1,
        badgesRemoved: [],
      });
      const badges = await container.dbPool.query(
        `select mb.badge_code, count(bp.mission_id)::integer as contributions
           from app.member_badges mb
           left join app.badge_participations bp on bp.member_badge_id = mb.id
          where mb.family_id = $1 and mb.member_id = $2
          group by mb.id`,
        [family.familyId, family.memberId],
      );
      expect(badges.rows).toEqual([{ badge_code: 'bronze', contributions: 5 }]);
    });

    it('CA-08 serializes concurrent reopenings and undoes the completion once', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family, [family.memberId]);
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      await container.completeTaskUseCase.execute(admin, taskId);
      const results = await Promise.allSettled([
        container.reopenTaskUseCase.execute(admin, taskId, false),
        container.reopenTaskUseCase.execute(admin, taskId, false),
      ]);
      expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
      const failure = results.find((result) => result.status === 'rejected');
      expect(failure).toMatchObject({ reason: { code: 'TASK_NOT_COMPLETED' } });
      const events = await container.dbPool.query(
        `select count(*)::integer as total from app.task_events
          where family_id = $1 and task_id = $2 and event_type = 'reopened'`,
        [family.familyId, taskId],
      );
      expect(events.rows[0].total).toBe(1);
    });
  },
);
