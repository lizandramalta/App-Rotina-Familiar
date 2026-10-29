/** PostgreSQL invariants for SPEC-008 phase 2 / SCRUM-45 (CA-07–CA-09). */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { GetRoutineUseCase } from '../../src/modules/routines/application/get-routine-use-case.js';
import { PostgresFamilySettingsRepository } from '../../src/modules/family/infrastructure/postgres-family-settings-repository.js';
import { PostgresRoutineRepository } from '../../src/modules/routines/infrastructure/postgres-routine-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-27T12:00:00.000Z');

interface FamilyFixture {
  readonly familyId: string;
  readonly memberId: string;
}

interface OccurrenceRow {
  id: string;
  original_date: string;
  scheduled_date: string;
  title: string;
  weight: number;
  note: string | null;
  status: string;
  deleted_at: Date | null;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Routine management persistence — SPEC-008 phase 2 / SCRUM-45',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const families: FamilyFixture[] = [];

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath))
        loadDotenv({ path: envPath });
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of families) {
          await container.dbPool.query(
            `delete from app.badge_participations where member_badge_id in
             (select id from app.member_badges where family_id = $1)`,
            [family.familyId],
          );
          for (const table of [
            'member_badges',
            'mission_participations',
            'mission_tasks',
            'missions',
            'completion_credits',
            'completions',
            'kids_signals',
            'task_events',
            'task_assignees',
            'task_occurrences',
            'routine_assignees',
            'routines',
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
    }, 90_000);

    async function seedFamily(): Promise<FamilyFixture> {
      const family = { familyId: randomUUID(), memberId: randomUUID() };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Routine management test', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.members
          (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $2, 'administrator', true, 'Test member', $3, $3)`,
        [family.memberId, family.familyId, NOW],
      );
      families.push(family);
      return family;
    }

    function actor(family: FamilyFixture): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.memberId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      };
    }

    async function createRoutine(family: FamilyFixture): Promise<string> {
      const routine = await container.createRoutineUseCase.execute({
        actor: actor(family),
        title: 'Original routine',
        weight: 1,
        assigneeIds: [family.memberId],
        note: null,
        startDate: '2026-10-06',
        frequencyDays: 7,
      });
      return routine.id;
    }

    async function occurrences(familyId: string, routineId: string): Promise<OccurrenceRow[]> {
      const rows = await container.dbPool.query<OccurrenceRow>(
        `select id, to_char(original_date, 'YYYY-MM-DD') as original_date,
                to_char(scheduled_date, 'YYYY-MM-DD') as scheduled_date,
                title, weight, note, status, deleted_at
           from app.task_occurrences
          where family_id = $1 and routine_id = $2
          order by original_date`,
        [familyId, routineId],
      );
      return rows.rows;
    }

    async function mission(
      family: FamilyFixture,
      taskIds: readonly string[],
      completed: boolean,
    ): Promise<string> {
      const missionId = randomUUID();
      await container.dbPool.query(
        `insert into app.missions (id, family_id, title, completed_at, created_at, updated_at)
         values ($1, $2, 'Test mission', $3, $4, $4)`,
        [missionId, family.familyId, completed ? NOW : null, NOW],
      );
      for (const taskId of taskIds) {
        await container.dbPool.query(
          `insert into app.mission_tasks (family_id, mission_id, task_id) values ($1, $2, $3)`,
          [family.familyId, missionId, taskId],
        );
      }
      return missionId;
    }

    it('CA-07 preserves individually moved dates, replaces editable fields and updates later materialization', async () => {
      const family = await seedFamily();
      const routineId = await createRoutine(family);
      const initial = await occurrences(family.familyId, routineId);
      const source = initial.find((row) => row.original_date === '2026-10-13');
      const moved = initial.find((row) => row.original_date === '2026-10-20');
      expect(source).toBeDefined();
      expect(moved).toBeDefined();
      await container.editTaskUseCase.execute({
        actor: actor(family),
        taskId: moved!.id,
        title: 'Individual title',
        weight: 3,
        scheduledDate: '2026-12-20',
        assigneeIds: [family.memberId],
        note: 'Individual note',
        signalResolution: undefined,
      });
      expect((await container.getRoutineUseCase.execute(actor(family), routineId)).title).toBe(
        'Original routine',
      );

      const result = await container.updateFutureRoutineUseCase.execute({
        actor: actor(family),
        routineId,
        fromTaskId: source!.id,
        title: 'Updated routine',
        weight: 2,
        assigneeIds: [],
        note: 'Updated note',
      });
      expect(result.updatedTaskIds).toContain(source!.id);
      expect(result.updatedTaskIds).toContain(moved!.id);
      const after = await occurrences(family.familyId, routineId);
      expect(after.find((row) => row.id === moved!.id)).toMatchObject({
        scheduled_date: '2026-12-20',
        title: 'Updated routine',
        weight: 2,
        note: 'Updated note',
        status: 'pending',
      });
      expect(after.find((row) => row.original_date === '2026-10-06')?.title).toBe(
        'Original routine',
      );
      const audit = await container.dbPool.query<{
        old_values: { title: string; scheduledDate: string };
      }>(
        `select old_values from app.task_events where family_id = $1 and task_id = $2
          and event_type = 'edited' order by created_at desc limit 1`,
        [family.familyId, moved!.id],
      );
      expect(audit.rows[0]?.old_values).toMatchObject({
        title: 'Individual title',
        scheduledDate: '2026-12-20',
      });

      const futureClock: Clock = {
        now: () => new Date('2026-12-02T12:00:00.000Z'),
        nowIsoString: () => '2026-12-02T12:00:00.000Z',
      };
      const getFuture = new GetRoutineUseCase({
        routineRepository: new PostgresRoutineRepository(),
        familySettingsRepository: new PostgresFamilySettingsRepository(),
        transactionRunner: container.transactionRunner,
        clock: futureClock,
      });
      await getFuture.execute(actor(family), routineId);
      const later = (await occurrences(family.familyId, routineId)).find(
        (row) => row.original_date === '2026-12-01',
      );
      expect(later).toMatchObject({ title: 'Updated routine', weight: 2, note: 'Updated note' });
      const assignees = await container.dbPool.query(
        `select member_id from app.task_assignees where family_id = $1 and task_id = $2`,
        [family.familyId, later!.id],
      );
      expect(assignees.rowCount).toBe(0);
    });

    it('CA-08 keeps completed/protected tasks, rejects an empty mission and stops materialization', async () => {
      const family = await seedFamily();
      const routineId = await createRoutine(family);
      const initial = await occurrences(family.familyId, routineId);
      const source = initial.find((row) => row.original_date === '2026-10-13')!;
      const completed = initial.find((row) => row.original_date === '2026-10-20')!;
      const protectedTask = initial.find((row) => row.original_date === '2026-10-27')!;
      const signaledTask = initial.find((row) => row.original_date === '2026-11-03')!;
      await container.completeTaskUseCase.execute(actor(family), completed.id);
      await mission(family, [protectedTask.id], true);
      const blockingMissionId = await mission(family, [source.id], false);

      await expect(
        container.updateFutureRoutineUseCase.execute({
          actor: actor(family),
          routineId,
          fromTaskId: protectedTask.id,
          title: 'Should not persist',
          weight: undefined,
          assigneeIds: undefined,
          note: undefined,
        }),
      ).rejects.toMatchObject({ code: 'MISSION_COMPLETED_PROTECTED' });
      expect((await container.getRoutineUseCase.execute(actor(family), routineId)).title).toBe(
        'Original routine',
      );

      await expect(
        container.deleteFutureRoutineTasksUseCase.execute({
          actor: actor(family),
          routineId,
          fromTaskId: source.id,
        }),
      ).rejects.toMatchObject({ code: 'MISSION_WOULD_HAVE_NO_TASKS' });
      expect(
        (await occurrences(family.familyId, routineId)).every((row) => row.deleted_at === null),
      ).toBe(true);
      await container.dbPool.query(
        `delete from app.mission_tasks where family_id = $1 and mission_id = $2`,
        [family.familyId, blockingMissionId],
      );
      await container.dbPool.query('delete from app.missions where family_id = $1 and id = $2', [
        family.familyId,
        blockingMissionId,
      ]);
      const closingMissionId = await mission(family, [source.id, completed.id], false);
      const kidId = randomUUID();
      const signalId = randomUUID();
      await container.dbPool.query(
        `insert into app.members
          (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $2, 'kids', false, 'Test kid', $3, $3)`,
        [kidId, family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
        [family.familyId, signaledTask.id, kidId],
      );
      await container.dbPool.query(
        `update app.task_occurrences set status = 'awaitingConfirmation'
          where family_id = $1 and id = $2`,
        [family.familyId, signaledTask.id],
      );
      await container.dbPool.query(
        `insert into app.kids_signals (id, family_id, task_id, signaled_by_id, created_at)
         values ($1, $2, $3, $4, $5)`,
        [signalId, family.familyId, signaledTask.id, kidId, NOW],
      );

      const result = await container.deleteFutureRoutineTasksUseCase.execute({
        actor: actor(family),
        routineId,
        fromTaskId: source.id,
      });
      expect(result.deletedTaskIds).toContain(source.id);
      expect(result.preservedTaskIds).toEqual(
        expect.arrayContaining([completed.id, protectedTask.id]),
      );
      const after = await occurrences(family.familyId, routineId);
      expect(after.find((row) => row.id === source.id)?.deleted_at).not.toBeNull();
      expect(after.find((row) => row.id === completed.id)?.deleted_at).toBeNull();
      expect(after.find((row) => row.id === protectedTask.id)?.deleted_at).toBeNull();
      const closedMission = await container.dbPool.query<{ completed_at: Date | null }>(
        `select completed_at from app.missions where family_id = $1 and id = $2`,
        [family.familyId, closingMissionId],
      );
      expect(closedMission.rows[0]?.completed_at).not.toBeNull();
      const discardedSignal = await container.dbPool.query<{ discarded_at: Date | null }>(
        `select discarded_at from app.kids_signals where family_id = $1 and id = $2`,
        [family.familyId, signalId],
      );
      expect(discardedSignal.rows[0]?.discarded_at).not.toBeNull();
      const beforeCount = after.length;
      const futureClock: Clock = {
        now: () => new Date('2026-12-02T12:00:00.000Z'),
        nowIsoString: () => '2026-12-02T12:00:00.000Z',
      };
      const getFuture = new GetRoutineUseCase({
        routineRepository: new PostgresRoutineRepository(),
        familySettingsRepository: new PostgresFamilySettingsRepository(),
        transactionRunner: container.transactionRunner,
        clock: futureClock,
      });
      const state = await getFuture.execute(actor(family), routineId);
      expect(state.isActive).toBe(false);
      expect((await occurrences(family.familyId, routineId)).length).toBe(beforeCount);
    });

    it('CA-09 isolates another family and rejects a same-family source from another routine', async () => {
      const owner = await seedFamily();
      const outsider = await seedFamily();
      const firstId = await createRoutine(owner);
      const secondId = await createRoutine(owner);
      const firstSource = (await occurrences(owner.familyId, firstId))[0]!;
      const secondSource = (await occurrences(owner.familyId, secondId))[0]!;
      await expect(
        container.updateFutureRoutineUseCase.execute({
          actor: actor(owner),
          routineId: firstId,
          fromTaskId: secondSource.id,
          title: 'New',
          weight: undefined,
          assigneeIds: undefined,
          note: undefined,
        }),
      ).rejects.toMatchObject({
        statusCode: 422,
        fieldErrors: { fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'] },
      });
      await expect(
        container.deleteFutureRoutineTasksUseCase.execute({
          actor: actor(outsider),
          routineId: firstId,
          fromTaskId: firstSource.id,
        }),
      ).rejects.toMatchObject({ statusCode: 404 });
    });
  },
);
