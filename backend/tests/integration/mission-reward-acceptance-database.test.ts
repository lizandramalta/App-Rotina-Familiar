/** SCRUM-88 / SPEC-017 phase 1: transaction, family isolation and concurrent acceptance. */
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

const NOW = new Date('2026-11-04T12:00:00.000Z');
// Item predefinido de RN42 (migration 0011): disponível a qualquer família.
const PREDEFINED_REWARD_ITEM_ID = 'b2811e28-9ad3-4000-8000-000000000001';
const OTHER_PREDEFINED_REWARD_ITEM_ID = 'b2811e28-9ad3-4000-8000-000000000002';

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'SCRUM-88 / SPEC-017 mission reward acceptance persistence',
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

    async function seedTask(family: FamilyFixture): Promise<string> {
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
         values ($1, $2, $3, $4, '2026-11-04', '2026-11-04', 'Test task', 2,
                 'pending', $5, $5)`,
        [taskId, family.familyId, templateId, `single:${taskId}`, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
        [family.familyId, taskId, family.memberId],
      );
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

    async function seedCompletedMission(family: FamilyFixture): Promise<string> {
      const taskId = await seedTask(family);
      const missionId = await seedMission(family, taskId);
      await container.completeTaskUseCase.execute(
        actor(family, family.adminId, MemberRole.ADMINISTRATOR),
        taskId,
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

    it('CA-01 persists a single accepted-reward snapshot and closes redemption', async () => {
      const family = await seedFamily();
      const missionId = await seedCompletedMission(family);
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);

      const result = await container.acceptMissionRewardUseCase.execute({
        actor: admin,
        missionId,
        rewardItemId: PREDEFINED_REWARD_ITEM_ID,
      });

      expect(result).toMatchObject({
        status: 'completed',
        isRedemptionAvailable: false,
        acceptedReward: { rewardItemId: PREDEFINED_REWARD_ITEM_ID, source: 'predefined' },
      });
      const row = await container.dbPool.query(
        `select accepted_reward_item_id, accepted_reward_title, accepted_reward_source,
                accepted_reward_details, accepted_reward_accepted_at
           from app.missions where family_id = $1 and id = $2`,
        [family.familyId, missionId],
      );
      expect(row.rows[0]).toMatchObject({
        accepted_reward_item_id: PREDEFINED_REWARD_ITEM_ID,
        accepted_reward_source: 'predefined',
      });
      expect(row.rows[0].accepted_reward_title).not.toBeNull();
      expect(row.rows[0].accepted_reward_accepted_at).not.toBeNull();
    });

    it('CA-05 a lost response is recovered by querying detail and list, for Admin and Kids', async () => {
      const family = await seedFamily();
      const missionId = await seedCompletedMission(family);
      const admin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      const kid = actor(family, family.kidId, MemberRole.KIDS);

      await container.acceptMissionRewardUseCase.execute({
        actor: admin,
        missionId,
        rewardItemId: PREDEFINED_REWARD_ITEM_ID,
      });

      const detail = await container.getMissionDetailUseCase.execute(admin, missionId);
      expect(detail).toMatchObject({
        isRedemptionAvailable: false,
        acceptedReward: { rewardItemId: PREDEFINED_REWARD_ITEM_ID, source: 'predefined' },
      });

      const kidsDetail = await container.getMissionDetailUseCase.execute(kid, missionId);
      expect(kidsDetail).not.toHaveProperty('isRedemptionAvailable');
      expect(kidsDetail).toMatchObject({
        acceptedReward: { rewardItemId: PREDEFINED_REWARD_ITEM_ID, source: 'predefined' },
      });

      const list = await container.listMissionsUseCase.execute(admin);
      expect(list.completed).toEqual([
        expect.objectContaining({
          id: missionId,
          isRedemptionAvailable: false,
          acceptedReward: expect.objectContaining({ rewardItemId: PREDEFINED_REWARD_ITEM_ID }),
        }),
      ]);

      const kidsList = await container.listMissionsUseCase.execute(kid);
      expect(kidsList.completed[0]).not.toHaveProperty('isRedemptionAvailable');
      expect(kidsList.completed[0]).toMatchObject({
        acceptedReward: expect.objectContaining({ rewardItemId: PREDEFINED_REWARD_ITEM_ID }),
      });
    });

    it('CA-03 hides a mission of another family as not found, without mutation', async () => {
      const family = await seedFamily();
      const other = await seedFamily();
      const missionId = await seedCompletedMission(family);

      await expect(
        container.acceptMissionRewardUseCase.execute({
          actor: actor(other, other.adminId, MemberRole.ADMINISTRATOR),
          missionId,
          rewardItemId: PREDEFINED_REWARD_ITEM_ID,
        }),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });

      const row = await container.dbPool.query(
        `select accepted_reward_item_id from app.missions where family_id = $1 and id = $2`,
        [family.familyId, missionId],
      );
      expect(row.rows[0].accepted_reward_item_id).toBeNull();
    });

    it('CA-04 refuses an in-progress mission without mutation', async () => {
      const family = await seedFamily();
      const taskId = await seedTask(family);
      const missionId = await seedMission(family, taskId);

      await expect(
        container.acceptMissionRewardUseCase.execute({
          actor: actor(family, family.adminId, MemberRole.ADMINISTRATOR),
          missionId,
          rewardItemId: PREDEFINED_REWARD_ITEM_ID,
        }),
      ).rejects.toMatchObject({ code: 'MISSION_REWARD_REDEMPTION_UNAVAILABLE' });

      const row = await container.dbPool.query(
        `select completed_at, accepted_reward_item_id from app.missions
          where family_id = $1 and id = $2`,
        [family.familyId, missionId],
      );
      expect(row.rows[0]).toEqual({ completed_at: null, accepted_reward_item_id: null });
    });

    it('CA-05 serializes two concurrent administrators into a single accepted snapshot', async () => {
      const family = await seedFamily();
      const missionId = await seedCompletedMission(family);
      const firstAdmin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);
      const secondAdmin = actor(family, family.adminId, MemberRole.ADMINISTRATOR);

      const results = await Promise.allSettled([
        container.acceptMissionRewardUseCase.execute({
          actor: firstAdmin,
          missionId,
          rewardItemId: PREDEFINED_REWARD_ITEM_ID,
        }),
        container.acceptMissionRewardUseCase.execute({
          actor: secondAdmin,
          missionId,
          rewardItemId: OTHER_PREDEFINED_REWARD_ITEM_ID,
        }),
      ]);

      expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
      const failure = results.find((result) => result.status === 'rejected');
      expect(failure).toMatchObject({ reason: { code: 'MISSION_REWARD_ALREADY_ACCEPTED' } });

      const row = await container.dbPool.query(
        `select accepted_reward_item_id from app.missions where family_id = $1 and id = $2`,
        [family.familyId, missionId],
      );
      // O snapshot persistido é de exatamente uma das duas tentativas.
      expect([PREDEFINED_REWARD_ITEM_ID, OTHER_PREDEFINED_REWARD_ITEM_ID]).toContain(
        row.rows[0].accepted_reward_item_id,
      );
    });
  },
);
