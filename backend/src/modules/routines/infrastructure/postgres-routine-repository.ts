import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  MaterializeBatchResult,
  RoutineRecord,
  RoutineRepositoryPort,
} from '../application/routine-repository-port.js';

interface RoutineRow {
  id: string;
  family_id: string;
  task_template_id: string;
  title: string;
  weight: number;
  note: string | null;
  frequency_days: number;
  start_date: string;
  is_active: boolean;
  generated_until: string | null;
  created_at: Date;
  assignee_ids: string[] | null;
}

function toRoutine(row: RoutineRow): RoutineRecord {
  return {
    id: row.id,
    familyId: row.family_id,
    taskTemplateId: row.task_template_id,
    title: row.title,
    weight: row.weight,
    note: row.note,
    assigneeIds: row.assignee_ids ?? [],
    frequencyDays: row.frequency_days,
    startDate: row.start_date,
    isActive: row.is_active,
    generatedUntil: row.generated_until,
    createdAt: row.created_at,
  };
}

const routineSelect = `
  select r.id, r.family_id, r.task_template_id, t.title, t.weight, t.note,
         r.frequency_days, to_char(r.start_date, 'YYYY-MM-DD') as start_date,
         r.is_active, to_char(r.generated_until, 'YYYY-MM-DD') as generated_until,
         r.created_at,
         coalesce(array_agg(a.member_id order by a.member_id) filter (where a.member_id is not null), '{}') as assignee_ids
    from app.routines r
    join app.task_templates t on t.family_id = r.family_id and t.id = r.task_template_id
    left join app.routine_assignees a on a.family_id = r.family_id and a.routine_id = r.id
   where r.family_id = $1 and r.id = $2
   group by r.id, t.title, t.weight, t.note`;

export class PostgresRoutineRepository implements RoutineRepositoryPort {
  public async insertRoutine(
    tx: TransactionContext,
    params: {
      readonly routineId: string;
      readonly familyId: string;
      readonly taskTemplateId: string;
      readonly frequencyDays: number;
      readonly startDate: string;
      readonly assigneeIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(
      `insert into app.routines
        (id, family_id, task_template_id, frequency_days, start_date, is_active, generated_until,
         created_at, updated_at)
       values ($1, $2, $3, $4, $5, true, null, $6, $6)`,
      [
        params.routineId,
        params.familyId,
        params.taskTemplateId,
        params.frequencyDays,
        params.startDate,
        params.now,
      ],
    );
    for (const memberId of params.assigneeIds) {
      await client.query(
        `insert into app.routine_assignees (family_id, routine_id, member_id) values ($1, $2, $3)`,
        [params.familyId, params.routineId, memberId],
      );
    }
  }

  public async findRoutine(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    forUpdate = false,
  ): Promise<RoutineRecord | undefined> {
    const client = asPostgresClient(tx);
    if (forUpdate) {
      await client.query(
        `select id from app.routines where family_id = $1 and id = $2 for update`,
        [familyId, routineId],
      );
    }
    const result = await client.query<RoutineRow>(routineSelect, [familyId, routineId]);
    const row = result.rows[0];
    return row === undefined ? undefined : toRoutine(row);
  }

  public async materializeBatch(
    tx: TransactionContext,
    params: {
      readonly routine: RoutineRecord;
      readonly horizon: string;
      readonly maxBatch: number;
      readonly now: Date;
    },
  ): Promise<MaterializeBatchResult> {
    const client = asPostgresClient(tx);
    const { routine } = params;

    const result = await client.query<{ batch_count: number; batch_max: string | null }>(
      `with bounds as (
         select case
           when $6::date is null or $6::date < $5::date then $5::date
           else $5::date + (ceil((($6::date - $5::date) + 1)::numeric / $4::numeric) * $4)::int
         end as range_start
       ),
       batch as (
         select gs::date as scheduled_date
           from bounds, generate_series(bounds.range_start, $7::date, ($4::text || ' days')::interval) as gs
          order by gs
          limit $8::int
       ),
       inserted as (
         insert into app.task_occurrences
           (id, family_id, task_template_id, routine_id, origin_key, original_date, scheduled_date,
            title, weight, note, status, created_at, updated_at)
         select gen_random_uuid(), $1, $2, $3,
                to_char(scheduled_date, 'YYYY-MM-DD'), scheduled_date, scheduled_date,
                $9, $10, $11, 'pending', $12, $12
           from batch
         on conflict (task_template_id, origin_key) do nothing
         returning id
       ),
       assignees_inserted as (
         insert into app.task_assignees (family_id, task_id, member_id)
         select $1, inserted.id, assignee_id
           from inserted, unnest($13::uuid[]) as assignee_id
         returning 1
       )
       select
         (select count(*) from batch)::int as batch_count,
         (select to_char(max(scheduled_date), 'YYYY-MM-DD') from batch) as batch_max`,
      [
        routine.familyId,
        routine.taskTemplateId,
        routine.id,
        routine.frequencyDays,
        routine.startDate,
        routine.generatedUntil,
        params.horizon,
        params.maxBatch,
        routine.title,
        routine.weight,
        routine.note,
        params.now,
        routine.assigneeIds,
      ],
    );

    const row = result.rows[0];
    if (row === undefined) {
      throw new Error('Routine materialization batch did not return a row.');
    }

    // Lote não atingiu o teto: a série se esgotou dentro de [cursor, horizonte],
    // então não há nada pendente até o horizonte atual, mesmo que `batch_max`
    // fique abaixo dele (ex.: início depois do horizonte, lote vazio).
    const isComplete = row.batch_count < params.maxBatch;
    const generatedUntil = isComplete ? params.horizon : (row.batch_max as string);

    await client.query(
      `update app.routines set generated_until = $3, updated_at = $4 where family_id = $1 and id = $2`,
      [routine.familyId, routine.id, generatedUntil, params.now],
    );

    return { generatedUntil, isComplete };
  }
}
