/**
 * Fechamento de missões, participações e badges (SPEC-014 Fase 1 / SCRUM-66).
 *
 * PostgreSQL real comprova o que dublês não alcançam: fechamento atômico com a
 * conclusão da tarefa, lock familiar, idempotência de participações/badges e
 * isolamento entre famílias.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-19T12:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly adminId: string;
  readonly memberId: string;
  readonly otherMemberId: string;
  readonly kidId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Mission closing persistence',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const seededFamilies: SeededFamily[] = [];

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
          const id = [family.familyId];
          await container.dbPool.query(
            `delete from app.badge_participations
              where member_badge_id in (select id from app.member_badges where family_id = $1)`,
            id,
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
          ]) {
            await container.dbPool.query(`delete from app.${table} where family_id = $1`, id);
          }
          await container.dbPool.query('delete from app.families where id = $1', id);
        }
      }
      await container?.dispose();
    });

    async function seedFamily(): Promise<SeededFamily> {
      const family = {
        familyId: randomUUID(),
        adminId: randomUUID(),
        memberId: randomUUID(),
        otherMemberId: randomUUID(),
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
        [family.otherMemberId, 'member', false],
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

    async function seedTask(family: SeededFamily, assigneeIds: readonly string[]): Promise<string> {
      const templateId = randomUUID();
      const taskId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Tarefa de teste', 2, $3, $3)`,
        [templateId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
          (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
           title, weight, status, created_at, updated_at)
         values ($1, $2, $3, $4, '2026-10-19', '2026-10-19', 'Tarefa de teste', 2,
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

    const admin = (family: SeededFamily): ActorContext => ({
      sessionId: randomUUID(),
      familyId: family.familyId,
      memberId: family.adminId,
      role: MemberRole.ADMINISTRATOR,
      isFamilyCreator: true,
    });

    const completeTask = (family: SeededFamily, taskId: string) =>
      container.completeTaskUseCase.execute(admin(family), taskId);

    const createMission = (family: SeededFamily, taskIds: readonly string[]) =>
      container.createMissionUseCase.execute({
        actor: admin(family),
        title: 'Arrumar o quintal',
        note: undefined,
        taskIds,
      });

    const participants = async (missionId: string): Promise<string[]> =>
      (
        await container.dbPool.query<{ member_id: string }>(
          `select member_id from app.mission_participations where mission_id = $1
            order by member_id`,
          [missionId],
        )
      ).rows.map((row) => row.member_id);

    it('CA-13/CA-20 creating with completed tasks closes at once, one participation per person', async () => {
      const family = await seedFamily();
      const taskA = await seedTask(family, [family.memberId]);
      const taskB = await seedTask(family, [family.memberId, family.otherMemberId]);
      await completeTask(family, taskA);
      await completeTask(family, taskB);

      const mission = await createMission(family, [taskA, taskB]);

      expect(mission).toMatchObject({ status: 'completed', isRedemptionAvailable: true });
      expect(await participants(mission.id)).toEqual(
        [family.memberId, family.otherMemberId].sort(),
      );
    });

    it('CA-15 completing the last pending task closes the mission in the same commit', async () => {
      const family = await seedFamily();
      const taskA = await seedTask(family, [family.memberId]);
      const taskB = await seedTask(family, [family.otherMemberId]);
      const mission = await createMission(family, [taskA, taskB]);
      expect(mission.status).toBe('inProgress');

      await completeTask(family, taskA);
      expect(
        (await container.getMissionDetailUseCase.execute(admin(family), mission.id)).status,
      ).toBe('inProgress');
      expect(await participants(mission.id)).toEqual([]);

      await completeTask(family, taskB);
      expect(
        (await container.getMissionDetailUseCase.execute(admin(family), mission.id)).status,
      ).toBe('completed');
      expect(await participants(mission.id)).toEqual(
        [family.memberId, family.otherMemberId].sort(),
      );
    });

    it('CA-14 unlinking every pending task during edition closes the mission', async () => {
      const family = await seedFamily();
      const done = await seedTask(family, [family.memberId]);
      const pending = await seedTask(family, [family.otherMemberId]);
      await completeTask(family, done);
      const mission = await createMission(family, [done, pending]);

      const edited = await container.editMissionUseCase.execute({
        actor: admin(family),
        missionId: mission.id,
        title: undefined,
        note: undefined,
        taskIds: [done],
      });

      expect(edited.status).toBe('completed');
      expect(await participants(mission.id)).toEqual([family.memberId]);
    });

    it('CA-10 refuses to edit a completed mission and keeps its data', async () => {
      const family = await seedFamily();
      const task = await seedTask(family, [family.memberId]);
      await completeTask(family, task);
      const mission = await createMission(family, [task]);

      await expect(
        container.editMissionUseCase.execute({
          actor: admin(family),
          missionId: mission.id,
          title: 'Outro título',
          note: undefined,
          taskIds: undefined,
        }),
      ).rejects.toMatchObject({ code: 'MISSION_COMPLETED_PROTECTED' });
      expect(
        (await container.getMissionDetailUseCase.execute(admin(family), mission.id)).title,
      ).toBe('Arrumar o quintal');
    });

    it('CA-16 concurrent edition and completion close once without duplicating effects', async () => {
      const family = await seedFamily();
      const done = await seedTask(family, [family.memberId]);
      const pending = await seedTask(family, [family.otherMemberId]);
      await completeTask(family, done);
      const mission = await createMission(family, [done, pending]);

      await Promise.allSettled([
        completeTask(family, pending),
        container.editMissionUseCase.execute({
          actor: admin(family),
          missionId: mission.id,
          title: undefined,
          note: undefined,
          taskIds: [done, pending],
        }),
      ]);

      expect(
        (await container.getMissionDetailUseCase.execute(admin(family), mission.id)).status,
      ).toBe('completed');
      const rows = await participants(mission.id);
      expect(rows).toEqual([...new Set(rows)]);
      expect(rows.length).toBeLessThanOrEqual(2);
      const badges = await container.dbPool.query(
        `select count(*)::int as total from app.member_badges where family_id = $1`,
        [family.familyId],
      );
      expect(badges.rows[0]).toEqual({ total: 0 });
    });

    it('CA-20 grants bronze once, on the fifth participation, with the five contributing missions', async () => {
      const family = await seedFamily();
      for (let index = 0; index < 4; index += 1) {
        const missionId = randomUUID();
        await container.dbPool.query(
          `insert into app.missions (id, family_id, title, completed_at, created_at, updated_at)
           values ($1, $2, 'Missão anterior', $3, $3, $3)`,
          [missionId, family.familyId, new Date(NOW.getTime() - (index + 1) * 60_000)],
        );
        await container.dbPool.query(
          `insert into app.mission_participations (family_id, mission_id, member_id, recorded_at)
           values ($1, $2, $3, $4)`,
          [family.familyId, missionId, family.memberId, NOW],
        );
      }
      const first = await seedTask(family, [family.memberId]);
      const second = await seedTask(family, [family.memberId]);
      await completeTask(family, first);
      await completeTask(family, second);

      const mission = await createMission(family, [first, second]);

      expect(await participants(mission.id)).toEqual([family.memberId]);
      const badges = await container.dbPool.query<{ badge_code: string; contributing: number }>(
        `select mb.badge_code,
                (select count(*)::int from app.badge_participations bp
                  where bp.member_badge_id = mb.id) as contributing
           from app.member_badges mb where mb.member_id = $1`,
        [family.memberId],
      );
      expect(badges.rows).toEqual([{ badge_code: 'bronze', contributing: 5 }]);
    });

    it('CA-16 two concurrent completions of the last two tasks close the mission exactly once', async () => {
      const family = await seedFamily();
      const taskA = await seedTask(family, [family.memberId]);
      const taskB = await seedTask(family, [family.otherMemberId]);
      const mission = await createMission(family, [taskA, taskB]);

      const results = await Promise.allSettled([
        completeTask(family, taskA),
        completeTask(family, taskB),
      ]);

      expect(results.every((result) => result.status === 'fulfilled')).toBe(true);
      expect(
        (await container.getMissionDetailUseCase.execute(admin(family), mission.id)).status,
      ).toBe('completed');
      expect(await participants(mission.id)).toEqual(
        [family.memberId, family.otherMemberId].sort(),
      );
    });

    it('CA-02 a demoted administrator session cannot create a mission', async () => {
      const family = await seedFamily();
      const task = await seedTask(family, [family.memberId]);
      await container.dbPool.query(`update app.members set role = 'member' where id = $1`, [
        family.adminId,
      ]);

      await expect(createMission(family, [task])).rejects.toMatchObject({
        code: 'ACTION_NOT_ALLOWED',
      });
      expect(
        (
          await container.dbPool.query(`select 1 from app.missions where family_id = $1`, [
            family.familyId,
          ])
        ).rowCount,
      ).toBe(0);
    });

    it('CA-04/CA-07 hides foreign missions and tasks across families', async () => {
      const family = await seedFamily();
      const foreign = await seedFamily();
      const foreignTask = await seedTask(foreign, [foreign.memberId]);
      const ownTask = await seedTask(family, [family.memberId]);
      const mission = await createMission(family, [ownTask]);

      await expect(createMission(family, [foreignTask])).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
        fieldErrors: { taskIds: ['TASK_NOT_IN_FAMILY'] },
      });
      await expect(
        container.getMissionDetailUseCase.execute(admin(foreign), mission.id),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
      await expect(
        container.editMissionUseCase.execute({
          actor: admin(foreign),
          missionId: mission.id,
          title: 'Invasão',
          note: undefined,
          taskIds: undefined,
        }),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
      const options = await container.getMissionTaskOptionsUseCase.execute(
        admin(foreign),
        undefined,
        undefined,
      );
      expect(options.items.map((item) => item.id)).not.toContain(ownTask);
    });
  },
);
