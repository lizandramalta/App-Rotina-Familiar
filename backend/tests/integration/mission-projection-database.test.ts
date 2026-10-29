/**
 * Projeções de missões e recompensas (SPEC-016 Fase 1 / SCRUM-85).
 *
 * PostgreSQL real comprova o que dublês não alcançam: contagens canônicas
 * agregadas por SQL, isolamento entre famílias e leitura consistente após
 * uma reabertura confirmada na mesma transação (BA-08).
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import type { MissionDetailResponse } from '../../src/modules/missions/application/mission-use-cases.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-28T12:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly adminId: string;
  readonly memberId: string;
  readonly kidId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Mission projections persistence',
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
      // Limpeza de 5 famílias via pool remoto excede o hookTimeout padrão (10s).
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
    }, 60_000);

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
      for (const [id, role, creator, name] of [
        [family.adminId, 'administrator', true, 'Ana'],
        [family.memberId, 'member', false, 'Bruno'],
        [family.kidId, 'kids', false, 'Caio'],
      ] as const) {
        await container.dbPool.query(
          `insert into app.members
            (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, $3, $4, $5, $6, $6)`,
          [id, family.familyId, role, creator, name, NOW],
        );
      }
      seededFamilies.push(family);
      return family;
    }

    async function seedTask(
      family: SeededFamily,
      assigneeIds: readonly string[],
      status: 'pending' | 'awaitingConfirmation' | 'completed' = 'pending',
    ): Promise<string> {
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
         values ($1, $2, $3, $4, '2026-10-28', '2026-10-28', 'Tarefa de teste', 2, $5, $6, $6)`,
        [taskId, family.familyId, templateId, `single:${taskId}`, status, NOW],
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

    const member = (family: SeededFamily): ActorContext => ({
      sessionId: randomUUID(),
      familyId: family.familyId,
      memberId: family.memberId,
      role: MemberRole.MEMBER,
      isFamilyCreator: false,
    });

    const kid = (family: SeededFamily): ActorContext => ({
      sessionId: randomUUID(),
      familyId: family.familyId,
      memberId: family.kidId,
      role: MemberRole.KIDS,
      isFamilyCreator: false,
    });

    const completeTask = (family: SeededFamily, taskId: string) =>
      container.completeTaskUseCase.execute(admin(family), taskId);

    const createMission = (family: SeededFamily, taskIds: readonly string[], title = 'Missão') =>
      container.createMissionUseCase.execute({
        actor: admin(family),
        title,
        note: undefined,
        taskIds,
      });

    it('CA-01 lists missions grouped by in-progress/completed, each task counted once', async () => {
      const family = await seedFamily();
      const doneA = await seedTask(family, [family.memberId], 'completed');
      const doneB = await seedTask(family, [family.memberId], 'completed');
      const pending = await seedTask(family, [family.memberId]);
      const inProgressMission = await createMission(family, [doneA, pending], 'Em andamento');
      const completedMission = await createMission(family, [doneB], 'Concluída');

      const page = await container.listMissionsUseCase.execute(admin(family));

      expect(page.inProgress).toEqual([
        expect.objectContaining({
          id: inProgressMission.id,
          taskCount: 2,
          completedTaskCount: 1,
          progressPercent: 50,
          isRedemptionAvailable: false,
          acceptedReward: null,
        }),
      ]);
      expect(page.completed).toEqual([
        expect.objectContaining({
          id: completedMission.id,
          taskCount: 1,
          completedTaskCount: 1,
          progressPercent: 100,
          isRedemptionAvailable: true,
          acceptedReward: null,
        }),
      ]);
    });

    it('CA-02 keeps a mission in progress while a linked task awaits confirmation', async () => {
      const family = await seedFamily();
      const done = await seedTask(family, [family.kidId], 'completed');
      const awaiting = await seedTask(family, [family.kidId], 'awaitingConfirmation');
      const mission = await createMission(family, [done, awaiting]);

      const detail = await container.getMissionDetailUseCase.execute(admin(family), mission.id);
      const page = await container.listMissionsUseCase.execute(admin(family));

      expect(detail).toMatchObject({ status: 'inProgress', progressPercent: 50 });
      expect(page.inProgress).toEqual([
        expect.objectContaining({ id: mission.id, completedTaskCount: 1, progressPercent: 50 }),
      ]);
      expect(page.completed).toEqual([]);
    });

    it('CA-03 detail shows participations/redemption to Admin/Membro and omits them for Kids', async () => {
      const family = await seedFamily();
      const taskA = await seedTask(family, [family.memberId]);
      const taskB = await seedTask(family, [family.kidId]);
      await completeTask(family, taskA);
      await completeTask(family, taskB);
      const mission = await createMission(family, [taskA, taskB]);
      expect(mission.status).toBe('completed');

      const adminView = await container.getMissionDetailUseCase.execute(admin(family), mission.id);
      expect(adminView).toMatchObject({
        status: 'completed',
        progressPercent: 100,
        isRedemptionAvailable: true,
        acceptedReward: null,
      });
      expect(adminView).toHaveProperty('participations');
      expect((adminView as MissionDetailResponse).participations).toEqual(
        expect.arrayContaining([
          { memberId: family.memberId, displayName: 'Bruno' },
          { memberId: family.kidId, displayName: 'Caio' },
        ]),
      );

      const memberView = await container.getMissionDetailUseCase.execute(
        member(family),
        mission.id,
      );
      expect(memberView).toHaveProperty('participations');

      const kidsView = await container.getMissionDetailUseCase.execute(kid(family), mission.id);
      expect(kidsView).not.toHaveProperty('participations');
      expect(kidsView).not.toHaveProperty('isRedemptionAvailable');
      expect(kidsView).not.toHaveProperty('familyId');
      expect(kidsView).toMatchObject({
        status: 'completed',
        progressPercent: 100,
        acceptedReward: null,
      });
    });

    it('CA-04 hides a mission of another family from list and detail', async () => {
      const family = await seedFamily();
      const foreign = await seedFamily();
      const ownTask = await seedTask(family, [family.memberId]);
      const foreignTask = await seedTask(foreign, [foreign.memberId]);
      const ownMission = await createMission(family, [ownTask]);
      await createMission(foreign, [foreignTask]);

      await expect(
        container.getMissionDetailUseCase.execute(admin(foreign), ownMission.id),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });

      const foreignPage = await container.listMissionsUseCase.execute(admin(foreign));
      const allForeignIds = [...foreignPage.inProgress, ...foreignPage.completed].map(
        (item) => item.id,
      );
      expect(allForeignIds).not.toContain(ownMission.id);
    });

    it('CA-06 reflects a confirmed reopening without the previous participations/reward', async () => {
      const family = await seedFamily();
      const taskA = await seedTask(family, [family.memberId]);
      const taskB = await seedTask(family, [family.memberId]);
      await completeTask(family, taskA);
      await completeTask(family, taskB);
      const mission = await createMission(family, [taskA, taskB]);
      expect(mission.status).toBe('completed');

      const beforeReopen = await container.getMissionDetailUseCase.execute(
        admin(family),
        mission.id,
      );
      expect((beforeReopen as MissionDetailResponse).participations).not.toEqual([]);

      await container.reopenTaskUseCase.execute(admin(family), taskA, true);

      const detail = await container.getMissionDetailUseCase.execute(admin(family), mission.id);
      expect(detail).toMatchObject({
        status: 'inProgress',
        progressPercent: 50,
        isRedemptionAvailable: false,
        acceptedReward: null,
      });
      expect((detail as MissionDetailResponse).participations).toEqual([]);

      const page = await container.listMissionsUseCase.execute(admin(family));
      expect(page.completed).toEqual([]);
      expect(page.inProgress).toEqual([
        expect.objectContaining({
          id: mission.id,
          progressPercent: 50,
          isRedemptionAvailable: false,
        }),
      ]);
    });
  },
);
