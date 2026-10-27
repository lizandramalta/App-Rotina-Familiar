import { randomUUID } from 'node:crypto';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  TaskRecord,
  TaskRepositoryPort,
  TaskStatus,
} from '../application/task-repository-port.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import type {
  FamilyCalendarRecord,
  OwnTaskPageCursor,
  OwnTaskProgressRecord,
  TaskQueryRepositoryPort,
} from '../application/task-query-repository-port.js';

interface TaskRow {
  id: string;
  family_id: string;
  title: string;
  weight: number;
  scheduled_date: string;
  note: string | null;
  status: TaskStatus;
  routine_id: string | null;
  created_at: Date;
  assignee_ids: string[] | null;
}

function toTask(row: TaskRow): TaskRecord {
  return {
    id: row.id,
    familyId: row.family_id,
    title: row.title,
    weight: row.weight,
    scheduledDate: row.scheduled_date,
    note: row.note,
    status: row.status,
    routineId: row.routine_id,
    createdAt: row.created_at,
    assigneeIds: row.assignee_ids ?? [],
  };
}

const taskSelect = `
  select t.id, t.family_id, t.title, t.weight,
         to_char(t.scheduled_date, 'YYYY-MM-DD') as scheduled_date,
         t.note, t.status, t.routine_id, t.created_at,
         coalesce(array_agg(a.member_id order by a.member_id) filter (where a.member_id is not null), '{}') as assignee_ids
    from app.task_occurrences t
    left join app.task_assignees a on a.family_id = t.family_id and a.task_id = t.id
   where t.family_id = $1 and t.id = $2 and t.deleted_at is null
   group by t.id`;

export class PostgresTaskRepository implements TaskRepositoryPort, TaskQueryRepositoryPort {
  public async insertTaskTemplate(
    tx: TransactionContext,
    params: {
      readonly taskTemplateId: string;
      readonly familyId: string;
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly now: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.task_templates
        (id, family_id, title, weight, note, created_at, updated_at)
       values ($1, $2, $3, $4, $5, $6, $6)`,
      [
        params.taskTemplateId,
        params.familyId,
        params.title,
        params.weight,
        params.note,
        params.now,
      ],
    );
  }

  public async insertSingleTask(
    tx: TransactionContext,
    params: {
      readonly taskTemplateId: string;
      readonly taskId: string;
      readonly familyId: string;
      readonly title: string;
      readonly weight: number;
      readonly scheduledDate: string;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord> {
    const client = asPostgresClient(tx);
    await this.insertTaskTemplate(tx, {
      taskTemplateId: params.taskTemplateId,
      familyId: params.familyId,
      title: params.title,
      weight: params.weight,
      note: params.note,
      now: params.now,
    });
    await client.query(
      `insert into app.task_occurrences
        (id, family_id, task_template_id, routine_id, origin_key, original_date, scheduled_date,
         title, weight, note, status, created_at, updated_at)
       values ($1, $2, $3, null, $4, $5, $5, $6, $7, $8, 'pending', $9, $9)`,
      [
        params.taskId,
        params.familyId,
        params.taskTemplateId,
        `single:${params.taskId}`,
        params.scheduledDate,
        params.title,
        params.weight,
        params.note,
        params.now,
      ],
    );
    await this.replaceAssignees(tx, params.familyId, params.taskId, params.assigneeIds);
    await this.insertEvent(tx, {
      familyId: params.familyId,
      taskId: params.taskId,
      actorId: params.actorId,
      eventType: 'created',
      oldValues: null,
      newValues: {
        title: params.title,
        weight: params.weight,
        scheduledDate: params.scheduledDate,
      },
      now: params.now,
    });
    return this.requireTask(tx, params.familyId, params.taskId);
  }

  public async findTask(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
    forUpdate = false,
  ): Promise<TaskRecord | undefined> {
    const client = asPostgresClient(tx);
    if (forUpdate) {
      await client.query(
        `select id from app.task_occurrences
          where family_id = $1 and id = $2 and deleted_at is null for update`,
        [familyId, taskId],
      );
    }
    const result = await client.query<TaskRow>(taskSelect, [familyId, taskId]);
    const row = result.rows[0];
    return row === undefined ? undefined : toTask(row);
  }

  public async findMemberRole(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
  ): Promise<MemberRole | undefined> {
    const result = await asPostgresClient(tx).query<{ role: string }>(
      `select role from app.members where family_id = $1 and id = $2`,
      [familyId, memberId],
    );
    const role = result.rows[0]?.role;
    return role !== undefined && isValidMemberRole(role) ? role : undefined;
  }

  public async findFamilyCalendar(
    tx: TransactionContext,
    familyId: string,
  ): Promise<FamilyCalendarRecord | undefined> {
    const result = await asPostgresClient(tx).query<{
      created_at: Date;
      timezone: string;
    }>(
      `select created_at, timezone
         from app.families
        where id = $1`,
      [familyId],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : { createdAt: row.created_at, timeZoneId: row.timezone };
  }

  public async findOwnTasksPage(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly referenceDate: string;
      readonly after: OwnTaskPageCursor | undefined;
      readonly limit: number;
    },
  ): Promise<readonly TaskRecord[]> {
    const result = await asPostgresClient(tx).query<TaskRow>(
      `select t.id, t.family_id, t.title, t.weight,
              to_char(t.scheduled_date, 'YYYY-MM-DD') as scheduled_date,
              t.note, t.status, t.routine_id, t.created_at,
              assignees.ids as assignee_ids
         from app.task_occurrences t
         cross join lateral (
           select coalesce(array_agg(a.member_id order by a.member_id), '{}') as ids
             from app.task_assignees a
            where a.family_id = t.family_id and a.task_id = t.id
         ) assignees
        where t.family_id = $1
          and t.scheduled_date = $3::date
          and t.deleted_at is null
          and exists (
            select 1
              from app.task_assignees mine
             where mine.family_id = t.family_id
               and mine.task_id = t.id
               and mine.member_id = $2
          )
          and ($4::uuid is null or t.id > $4::uuid)
        order by t.id asc
        limit $5`,
      [
        params.familyId,
        params.memberId,
        params.referenceDate,
        params.after?.id ?? null,
        params.limit,
      ],
    );
    return result.rows.map(toTask);
  }

  public async countOwnTasksProgress(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly referenceDate: string;
    },
  ): Promise<OwnTaskProgressRecord> {
    const result = await asPostgresClient(tx).query<{
      total: number;
      completed: number;
    }>(
      `select count(*)::integer as total,
              count(*) filter (where t.status = 'completed')::integer as completed
         from app.task_occurrences t
        where t.family_id = $1
          and t.scheduled_date = $3::date
          and t.deleted_at is null
          and exists (
            select 1
              from app.task_assignees mine
             where mine.family_id = t.family_id
               and mine.task_id = t.id
               and mine.member_id = $2
          )`,
      [params.familyId, params.memberId, params.referenceDate],
    );
    const row = result.rows[0];
    if (row === undefined) {
      throw new TypeError('Own task progress aggregation did not return a row.');
    }
    return row;
  }

  public async countFamilyMembers(
    tx: TransactionContext,
    familyId: string,
    memberIds: readonly string[],
  ): Promise<number> {
    const result = await asPostgresClient(tx).query<{ total: string }>(
      `select count(*) as total from app.members
        where family_id = $1 and id = any($2::uuid[])`,
      [familyId, memberIds],
    );
    return Number(result.rows[0]?.total ?? 0);
  }

  public async hasCompletedMission(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `select 1 from app.mission_tasks mt
        join app.missions m on m.family_id = mt.family_id and m.id = mt.mission_id
       where mt.family_id = $1 and mt.task_id = $2 and m.completed_at is not null
       limit 1`,
      [familyId, taskId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  public async isOnlyTaskOfAnActiveMission(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `select 1 from app.mission_tasks current_link
        join app.missions m
          on m.family_id = current_link.family_id and m.id = current_link.mission_id
       where current_link.family_id = $1
         and current_link.task_id = $2
         and m.completed_at is null
         and not exists (
           select 1 from app.mission_tasks other_link
            where other_link.family_id = current_link.family_id
              and other_link.mission_id = current_link.mission_id
              and other_link.task_id <> current_link.task_id
         )
       limit 1`,
      [familyId, taskId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  public async hasCurrentSignal(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `select 1 from app.kids_signals
        where family_id = $1 and task_id = $2 and discarded_at is null limit 1`,
      [familyId, taskId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  public async hasKidsAssignee(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `select 1
         from app.task_assignees a
         join app.members m on m.family_id = a.family_id and m.id = a.member_id
        where a.family_id = $1 and a.task_id = $2 and m.role = 'kids'
        limit 1`,
      [familyId, taskId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  public async completeTask(
    tx: TransactionContext,
    params: {
      readonly task: TaskRecord;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord> {
    const client = asPostgresClient(tx);
    const finalAssigneeIds =
      params.task.assigneeIds.length === 0 ? [params.actorId] : params.task.assigneeIds;

    if (params.task.assigneeIds.length === 0) {
      await this.replaceAssignees(tx, params.task.familyId, params.task.id, finalAssigneeIds);
    }

    await client.query(
      `update app.task_occurrences
          set status = 'completed', updated_at = $3
        where family_id = $1 and id = $2`,
      [params.task.familyId, params.task.id, params.now],
    );

    const completionId = randomUUID();
    await client.query(
      `insert into app.completions (id, family_id, task_id, performed_by_id, completed_at)
       values ($1, $2, $3, $4, $5)`,
      [completionId, params.task.familyId, params.task.id, params.actorId, params.now],
    );
    for (const memberId of finalAssigneeIds) {
      await client.query(
        `insert into app.completion_credits (completion_id, family_id, member_id, weight)
         values ($1, $2, $3, $4)`,
        [completionId, params.task.familyId, memberId, params.task.weight],
      );
    }
    await this.insertEvent(tx, {
      familyId: params.task.familyId,
      taskId: params.task.id,
      actorId: params.actorId,
      eventType: 'completed',
      oldValues: { status: params.task.status, assigneeIds: params.task.assigneeIds },
      newValues: { status: 'completed', assigneeIds: finalAssigneeIds, completionId },
      now: params.now,
    });
    return this.requireTask(tx, params.task.familyId, params.task.id);
  }

  public async reopenTask(
    tx: TransactionContext,
    params: { readonly task: TaskRecord; readonly actorId: string; readonly now: Date },
  ): Promise<TaskRecord> {
    const client = asPostgresClient(tx);
    const completion = await client.query<{ id: string }>(
      `update app.completions
          set undone_at = $3, undone_by_id = $4
        where family_id = $1 and task_id = $2 and undone_at is null
        returning id`,
      [params.task.familyId, params.task.id, params.now, params.actorId],
    );
    const completionId = completion.rows[0]?.id;
    if (completionId === undefined || completion.rowCount !== 1) {
      throw new Error('A completed task has no single current completion.');
    }
    await client.query(
      `update app.task_occurrences
          set status = 'pending', updated_at = $3
        where family_id = $1 and id = $2 and status = 'completed'`,
      [params.task.familyId, params.task.id, params.now],
    );
    await this.insertEvent(tx, {
      familyId: params.task.familyId,
      taskId: params.task.id,
      actorId: params.actorId,
      eventType: 'reopened',
      oldValues: { status: 'completed', completionId },
      newValues: { status: 'pending', assigneeIds: params.task.assigneeIds },
      now: params.now,
    });
    return this.requireTask(tx, params.task.familyId, params.task.id);
  }

  public async updateTask(
    tx: TransactionContext,
    params: {
      readonly task: TaskRecord;
      readonly title: string;
      readonly weight: number;
      readonly scheduledDate: string;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly status: TaskStatus;
      readonly discardSignal: boolean;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord> {
    const client = asPostgresClient(tx);
    const oldValues = {
      title: params.task.title,
      weight: params.task.weight,
      scheduledDate: params.task.scheduledDate,
      note: params.task.note,
      assigneeIds: params.task.assigneeIds,
      status: params.task.status,
    };
    // Uma edição individual de ocorrência não redefine o template compartilhado
    // da rotina; só UpdateFutureRoutine altera a configuração das próximas.
    if (params.task.routineId === null) {
      await client.query(
        `update app.task_templates
            set title = $3, weight = $4, note = $5, updated_at = $6
          where family_id = $1 and id = (
            select task_template_id from app.task_occurrences where family_id = $1 and id = $2
          )`,
        [
          params.task.familyId,
          params.task.id,
          params.title,
          params.weight,
          params.note,
          params.now,
        ],
      );
    }
    await client.query(
      `update app.task_occurrences
          set title = $3, weight = $4, scheduled_date = $5, note = $6, status = $7, updated_at = $8
        where family_id = $1 and id = $2`,
      [
        params.task.familyId,
        params.task.id,
        params.title,
        params.weight,
        params.scheduledDate,
        params.note,
        params.status,
        params.now,
      ],
    );
    await this.replaceAssignees(tx, params.task.familyId, params.task.id, params.assigneeIds);
    if (params.task.status === 'completed') {
      const completionResult = await client.query<{ id: string }>(
        `select id from app.completions
          where family_id = $1 and task_id = $2 and undone_at is null for update`,
        [params.task.familyId, params.task.id],
      );
      const completionId = completionResult.rows[0]?.id;
      if (completionId !== undefined) {
        await client.query(`delete from app.completion_credits where completion_id = $1`, [
          completionId,
        ]);
        for (const memberId of params.assigneeIds) {
          await client.query(
            `insert into app.completion_credits (completion_id, family_id, member_id, weight)
             values ($1, $2, $3, $4)`,
            [completionId, params.task.familyId, memberId, params.weight],
          );
        }
      }
    }
    if (params.discardSignal) {
      await client.query(
        `update app.kids_signals set discarded_at = $3
          where family_id = $1 and task_id = $2 and discarded_at is null`,
        [params.task.familyId, params.task.id, params.now],
      );
    }
    await this.insertEvent(tx, {
      familyId: params.task.familyId,
      taskId: params.task.id,
      actorId: params.actorId,
      eventType: 'edited',
      oldValues,
      newValues: {
        title: params.title,
        weight: params.weight,
        scheduledDate: params.scheduledDate,
        note: params.note,
        assigneeIds: params.assigneeIds,
        status: params.status,
      },
      now: params.now,
    });
    return this.requireTask(tx, params.task.familyId, params.task.id);
  }

  public async deleteTask(
    tx: TransactionContext,
    params: { readonly task: TaskRecord; readonly actorId: string; readonly now: Date },
  ): Promise<readonly string[]> {
    const client = asPostgresClient(tx);
    await client.query(
      `update app.kids_signals set discarded_at = $3
        where family_id = $1 and task_id = $2 and discarded_at is null`,
      [params.task.familyId, params.task.id, params.now],
    );
    // Missões que perderam o vínculo precisam ser reavaliadas (SPEC-014 CA-21).
    const unlinked = await client.query<{ mission_id: string }>(
      `delete from app.mission_tasks where family_id = $1 and task_id = $2 returning mission_id`,
      [params.task.familyId, params.task.id],
    );
    await client.query(
      `update app.task_occurrences set deleted_at = $3, updated_at = $3
        where family_id = $1 and id = $2`,
      [params.task.familyId, params.task.id, params.now],
    );
    await this.insertEvent(tx, {
      familyId: params.task.familyId,
      taskId: params.task.id,
      actorId: params.actorId,
      eventType: 'deleted',
      oldValues: { status: params.task.status, assigneeIds: params.task.assigneeIds },
      newValues: null,
      now: params.now,
    });
    return unlinked.rows.map((row) => row.mission_id);
  }

  private async replaceAssignees(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
    assigneeIds: readonly string[],
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(`delete from app.task_assignees where family_id = $1 and task_id = $2`, [
      familyId,
      taskId,
    ]);
    for (const memberId of assigneeIds) {
      await client.query(
        `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
        [familyId, taskId, memberId],
      );
    }
  }

  private async requireTask(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<TaskRecord> {
    const task = await this.findTask(tx, familyId, taskId);
    if (task === undefined) {
      throw new Error('Task was unexpectedly unavailable after a write.');
    }
    return task;
  }

  private async insertEvent(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskId: string;
      readonly actorId: string;
      readonly eventType: 'created' | 'edited' | 'deleted' | 'completed' | 'reopened';
      readonly oldValues: object | null;
      readonly newValues: object | null;
      readonly now: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.task_events
        (id, family_id, task_id, actor_id, event_type, old_values, new_values, created_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        randomUUID(),
        params.familyId,
        params.taskId,
        params.actorId,
        params.eventType,
        params.oldValues,
        params.newValues,
        params.now,
      ],
    );
  }
}
