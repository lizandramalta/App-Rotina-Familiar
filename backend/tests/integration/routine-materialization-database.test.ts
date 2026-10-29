/**
 * Materialização de rotina (SPEC-008 Fase 1 / SCRUM-43).
 *
 * PostgreSQL real comprova o que dublês não alcançam: insert em lote via
 * `generate_series`, avanço do cursor `generated_until` entre chamadas sem
 * duplicar ocorrência (`ON CONFLICT`), e isolamento entre famílias.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { CreateRoutineUseCase } from '../../src/modules/routines/application/create-routine-use-case.js';
import { GetRoutineUseCase } from '../../src/modules/routines/application/get-routine-use-case.js';
import { MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH } from '../../src/modules/routines/application/routine-repository-port.js';
import { PostgresRoutineRepository } from '../../src/modules/routines/infrastructure/postgres-routine-repository.js';
import { PostgresFamilySettingsRepository } from '../../src/modules/family/infrastructure/postgres-family-settings-repository.js';
import { PostgresTaskRepository } from '../../src/modules/tasks/infrastructure/postgres-task-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-09T12:00:00.000Z');
const TIME_ZONE_ID = 'America/Sao_Paulo';
// materializationHorizon(NOW, TIME_ZONE_ID) = fim do mês seguinte a outubro/2026.
const HORIZON = '2026-11-30';

interface SeededFamily {
  readonly familyId: string;
  readonly adminId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Routine materialization persistence — SPEC-008',
  { timeout: 120_000 },
  () => {
    let container: ApplicationContainer;
    const taskRepository = new PostgresTaskRepository();
    const routineRepository = new PostgresRoutineRepository();
    const familySettingsRepository = new PostgresFamilySettingsRepository();
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
      // O lote diário de 2014 em diante soma milhares de linhas: a limpeza por
      // família/tabela pode passar do timeout padrão de hook (10s).
    }, 60_000);

    const createRoutine = () =>
      new CreateRoutineUseCase({
        taskRepository,
        routineRepository,
        familySettingsRepository,
        transactionRunner: container.transactionRunner,
        clock,
      });

    const getRoutine = () =>
      new GetRoutineUseCase({
        routineRepository,
        familySettingsRepository,
        transactionRunner: container.transactionRunner,
        clock,
      });

    async function seedFamily(): Promise<SeededFamily> {
      const family = { familyId: randomUUID(), adminId: randomUUID() };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', $2, $3, $3)`,
        [family.familyId, TIME_ZONE_ID, NOW],
      );
      await container.dbPool.query(
        `insert into app.members
          (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $2, 'administrator', true, 'Pessoa de teste', $3, $3)`,
        [family.adminId, family.familyId, NOW],
      );
      seededFamilies.push(family);
      return family;
    }

    function actor(family: SeededFamily): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.adminId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      };
    }

    async function countOccurrences(familyId: string): Promise<number> {
      const result = await container.dbPool.query(
        `select count(*) as total from app.task_occurrences where family_id = $1`,
        [familyId],
      );
      return Number((result.rows[0] as { total: string }).total);
    }

    function expectedOccurrenceCount(startDate: string, frequencyDays: number): number {
      const days = Math.round((Date.parse(HORIZON) - Date.parse(startDate)) / 86_400_000) + 1;
      return Math.floor((days - 1) / frequencyDays) + 1;
    }

    it('CA-05 materializes a far-past daily routine across multiple batches without duplicating rows', async () => {
      const family = await seedFamily();
      const startDate = '2014-01-01';
      const expectedTotal = expectedOccurrenceCount(startDate, 1);
      // A faixa precisa exceder um único lote para este teste valer algo.
      expect(expectedTotal).toBeGreaterThan(MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH);

      const created = await createRoutine().execute({
        actor: actor(family),
        title: 'Tarefa diária antiga',
        weight: 1,
        assigneeIds: [],
        note: null,
        startDate,
        frequencyDays: 1,
      });

      expect(created.materializationState).toBe('pending');
      expect(await countOccurrences(family.familyId)).toBe(
        MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
      );

      let state = created.materializationState;
      let previousCount = await countOccurrences(family.familyId);
      let iterations = 0;
      while (state === 'pending' && iterations < 20) {
        const result = await getRoutine().execute(actor(family), created.id);
        const count = await countOccurrences(family.familyId);

        expect(count).toBeGreaterThanOrEqual(previousCount);
        expect(count).toBeLessThanOrEqual(expectedTotal);

        state = result.materializationState;
        previousCount = count;
        iterations += 1;
      }

      expect(state).toBe('complete');
      expect(previousCount).toBe(expectedTotal);

      // Idempotência: uma consulta extra depois de completo não insere nada novo.
      const again = await getRoutine().execute(actor(family), created.id);
      expect(again.materializationState).toBe('complete');
      expect(await countOccurrences(family.familyId)).toBe(expectedTotal);
    });

    it.each([1, 7, 14, 21, 28])(
      'CA-01/CA-05 materializes every allowed frequency without gaps or duplicates (every %d days)',
      async (frequencyDays) => {
        const family = await seedFamily();
        const startDate = '2026-10-10';
        const expectedTotal = expectedOccurrenceCount(startDate, frequencyDays);

        const created = await createRoutine().execute({
          actor: actor(family),
          title: `Rotina a cada ${frequencyDays} dias`,
          weight: 1,
          assigneeIds: [],
          note: null,
          startDate,
          frequencyDays,
        });

        expect(created.materializationState).toBe('complete');

        const rows = await container.dbPool.query<{ scheduled_date: string }>(
          `select to_char(scheduled_date, 'YYYY-MM-DD') as scheduled_date
             from app.task_occurrences
            where family_id = $1
            order by scheduled_date`,
          [family.familyId],
        );
        expect(rows.rowCount).toBe(expectedTotal);
        const dates = rows.rows.map((row) => row.scheduled_date);
        expect(new Set(dates).size).toBe(dates.length);
        expect(dates[0]).toBe(startDate);
        expect(dates[dates.length - 1] <= HORIZON).toBe(true);

        // Retentativa: não duplica.
        await getRoutine().execute(actor(family), created.id);
        expect(await countOccurrences(family.familyId)).toBe(expectedTotal);
      },
    );

    it('CA-01 persists the routine assignees and copies them to every materialized occurrence', async () => {
      const family = await seedFamily();
      const created = await createRoutine().execute({
        actor: actor(family),
        title: 'Rotina com responsável',
        weight: 1,
        assigneeIds: [family.adminId],
        note: null,
        startDate: '2026-10-10',
        frequencyDays: 7,
      });

      expect(created.assigneeIds).toEqual([family.adminId]);

      const assignees = await container.dbPool.query<{ task_id: string }>(
        `select task_id from app.task_assignees where family_id = $1 and member_id = $2`,
        [family.familyId, family.adminId],
      );
      const occurrences = await container.dbPool.query(
        `select id from app.task_occurrences where family_id = $1`,
        [family.familyId],
      );
      expect(assignees.rowCount).toBe(occurrences.rowCount);
    });

    it('CA-04 hides a routine from another family', async () => {
      const owner = await seedFamily();
      const outsider = await seedFamily();
      const created = await createRoutine().execute({
        actor: actor(owner),
        title: 'Rotina da outra família',
        weight: 1,
        assigneeIds: [],
        note: null,
        startDate: '2026-10-10',
        frequencyDays: 7,
      });

      await expect(getRoutine().execute(actor(outsider), created.id)).rejects.toMatchObject({
        code: 'RESOURCE_NOT_FOUND',
      });
    });
  },
);
