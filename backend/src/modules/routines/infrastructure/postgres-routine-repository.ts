import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  MaterializeBatchResult,
  RoutineOccurrenceRecord,
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

interface OccurrenceRow {
  id: string;
  routine_id: string | null;
  original_date: string;
  scheduled_date: string;
  status: RoutineOccurrenceRecord['status'];
  is_protected: boolean;
}

function toOccurrence(row: OccurrenceRow): RoutineOccurrenceRecord {
  return {
    id: row.id,
    routineId: row.routine_id,
    originalDate: row.original_date,
    scheduledDate: row.scheduled_date,
    status: row.status,
    isProtected: row.is_protected,
  };
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
  public async findSourceOccurrence(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<RoutineOccurrenceRecord | undefined> {
    const result = await asPostgresClient(tx).query<OccurrenceRow>(
      `select t.id, t.routine_id,
              to_char(t.original_date, 'YYYY-MM-DD') as original_date,
              to_char(t.scheduled_date, 'YYYY-MM-DD') as scheduled_date, t.status,
              exists (
                select 1 from app.mission_tasks mt
                join app.missions m on m.family_id = mt.family_id and m.id = mt.mission_id
                where mt.family_id = t.family_id and mt.task_id = t.id and m.completed_at is not null
              ) as is_protected
         from app.task_occurrences t
        where t.family_id = $1 and t.id = $2 and t.deleted_at is null
        for update of t`,
      [familyId, taskId],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : toOccurrence(row);
  }

  public async listFutureOccurrences(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    fromOriginalDate: string,
    taskTemplateId: string,
  ): Promise<readonly RoutineOccurrenceRecord[]> {
    const result = await asPostgresClient(tx).query<OccurrenceRow>(
      `select t.id, t.routine_id,
              to_char(t.original_date, 'YYYY-MM-DD') as original_date,
              to_char(t.scheduled_date, 'YYYY-MM-DD') as scheduled_date, t.status,
              exists (
                select 1 from app.mission_tasks mt
                join app.missions m on m.family_id = mt.family_id and m.id = mt.mission_id
                where mt.family_id = t.family_id and mt.task_id = t.id and m.completed_at is not null
              ) as is_protected
         from app.task_occurrences t
        where t.family_id = $1 and t.routine_id = $2 and t.task_template_id = $4
          and t.original_date >= $3::date and t.deleted_at is null
        order by t.original_date, t.id
        for update of t`,
      [familyId, routineId, fromOriginalDate, taskTemplateId],
    );
    return result.rows.map(toOccurrence);
  }

  public async updateConfiguration(
    tx: TransactionContext,
    params: {
      readonly routine: RoutineRecord;
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(
      `update app.task_templates set title = $3, weight = $4, note = $5, updated_at = $6
        where family_id = $1 and id = $2`,
      [
        params.routine.familyId,
        params.routine.taskTemplateId,
        params.title,
        params.weight,
        params.note,
        params.now,
      ],
    );
    await client.query(
      `delete from app.routine_assignees where family_id = $1 and routine_id = $2`,
      [params.routine.familyId, params.routine.id],
    );
    if (params.assigneeIds.length > 0) {
      await client.query(
        `insert into app.routine_assignees (family_id, routine_id, member_id)
         select $1, $2, member_id from unnest($3::uuid[]) as assignee(member_id)`,
        [params.routine.familyId, params.routine.id, params.assigneeIds],
      );
    }
    await client.query(`update app.routines set updated_at = $3 where family_id = $1 and id = $2`, [
      params.routine.familyId,
      params.routine.id,
      params.now,
    ]);
  }

  public async updateOccurrences(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskIds: readonly string[];
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<void> {
    if (params.taskIds.length === 0) return;
    const client = asPostgresClient(tx);
    // O evento captura os valores anteriores antes da atualização em lote.
    await client.query(
      `insert into app.task_events
         (id, family_id, task_id, actor_id, event_type, old_values, new_values, created_at)
       select gen_random_uuid(), t.family_id, t.id, $3, 'edited',
              jsonb_build_object('title', t.title, 'weight', t.weight,
                'scheduledDate', to_char(t.scheduled_date, 'YYYY-MM-DD'), 'note', t.note,
                'assigneeIds', coalesce((select jsonb_agg(a.member_id order by a.member_id)
                  from app.task_assignees a where a.family_id = t.family_id and a.task_id = t.id), '[]'::jsonb),
                'status', t.status),
              jsonb_build_object('title', $5::text, 'weight', $6::int,
                'scheduledDate', to_char(t.scheduled_date, 'YYYY-MM-DD'), 'note', $7::text,
                'assigneeIds', $8::uuid[], 'status', t.status), $4
         from app.task_occurrences t
        where t.family_id = $1 and t.id = any($2::uuid[]) and t.deleted_at is null`,
      [
        params.familyId,
        params.taskIds,
        params.actorId,
        params.now,
        params.title,
        params.weight,
        params.note,
        params.assigneeIds,
      ],
    );
    await client.query(
      `update app.task_occurrences set title = $3, weight = $4, note = $5, updated_at = $6
        where family_id = $1 and id = any($2::uuid[]) and deleted_at is null`,
      [params.familyId, params.taskIds, params.title, params.weight, params.note, params.now],
    );
    await client.query(
      `delete from app.task_assignees where family_id = $1 and task_id = any($2::uuid[])`,
      [params.familyId, params.taskIds],
    );
    if (params.assigneeIds.length > 0) {
      await client.query(
        `insert into app.task_assignees (family_id, task_id, member_id)
         select $1, task.id, assignee.member_id
           from unnest($2::uuid[]) as task(id)
          cross join unnest($3::uuid[]) as assignee(member_id)`,
        [params.familyId, params.taskIds, params.assigneeIds],
      );
    }
  }

  public async wouldEmptyActiveMission(
    tx: TransactionContext,
    familyId: string,
    taskIds: readonly string[],
  ): Promise<boolean> {
    if (taskIds.length === 0) return false;
    const result = await asPostgresClient(tx).query(
      `select 1 from app.missions m
         join app.mission_tasks mt on mt.family_id = m.family_id and mt.mission_id = m.id
        where m.family_id = $1 and m.completed_at is null
        group by m.id
       having bool_and(mt.task_id = any($2::uuid[]))
        limit 1`,
      [familyId, taskIds],
    );
    return (result.rowCount ?? 0) > 0;
  }

  public async deleteOccurrences(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<readonly string[]> {
    if (params.taskIds.length === 0) return [];
    const client = asPostgresClient(tx);
    await client.query(
      `insert into app.task_events
         (id, family_id, task_id, actor_id, event_type, old_values, new_values, created_at)
       select gen_random_uuid(), t.family_id, t.id, $3, 'deleted',
              jsonb_build_object('title', t.title, 'weight', t.weight,
                'scheduledDate', to_char(t.scheduled_date, 'YYYY-MM-DD'), 'note', t.note,
                'assigneeIds', coalesce((select jsonb_agg(a.member_id order by a.member_id)
                  from app.task_assignees a where a.family_id = t.family_id and a.task_id = t.id), '[]'::jsonb),
                'status', t.status), null, $4
         from app.task_occurrences t
        where t.family_id = $1 and t.id = any($2::uuid[]) and t.deleted_at is null`,
      [params.familyId, params.taskIds, params.actorId, params.now],
    );
    await client.query(
      `update app.kids_signals set discarded_at = $3
        where family_id = $1 and task_id = any($2::uuid[]) and discarded_at is null`,
      [params.familyId, params.taskIds, params.now],
    );
    const unlinked = await client.query<{ mission_id: string }>(
      `delete from app.mission_tasks
        where family_id = $1 and task_id = any($2::uuid[])
        returning mission_id`,
      [params.familyId, params.taskIds],
    );
    await client.query(
      `update app.task_occurrences set deleted_at = $3, updated_at = $3
        where family_id = $1 and id = any($2::uuid[]) and deleted_at is null`,
      [params.familyId, params.taskIds, params.now],
    );
    return unlinked.rows.map((row) => row.mission_id);
  }

  public async endGeneration(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    now: Date,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.routines set is_active = false, deactivated_at = $3, updated_at = $3
        where family_id = $1 and id = $2`,
      [familyId, routineId, now],
    );
  }
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
