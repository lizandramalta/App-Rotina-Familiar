import { randomUUID } from 'node:crypto';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  ClosedMission,
  MissionRecord,
  MissionRepositoryPort,
  MissionSummaryRecord,
  MissionTaskOptionRecord,
  PageCursor,
} from '../application/mission-repository-port.js';

interface MissionRow {
  id: string;
  family_id: string;
  title: string;
  note: string | null;
  completed_at: Date | null;
  created_at: Date;
  task_ids: string[] | null;
}

interface MissionSummaryRow {
  id: string;
  title: string;
  completed_at: Date | null;
  created_at: Date;
  task_count: string;
  completed_task_count: string;
}

interface TaskOptionRow {
  id: string;
  title: string;
  weight: number;
  scheduled_date: string;
  status: MissionTaskOptionRecord['status'];
  assignee_ids: string[] | null;
}

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (character) => `\\${character}`);
}

export class PostgresMissionRepository implements MissionRepositoryPort {
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

  public async countFamilyTasks(
    tx: TransactionContext,
    familyId: string,
    taskIds: readonly string[],
  ): Promise<number> {
    const result = await asPostgresClient(tx).query<{ total: string }>(
      `select count(*)::text as total
         from app.task_occurrences
        where family_id = $1 and id = any($2::uuid[]) and deleted_at is null`,
      [familyId, taskIds],
    );
    return Number(result.rows[0]?.total ?? 0);
  }

  public async insertMission(
    tx: TransactionContext,
    params: {
      readonly missionId: string;
      readonly familyId: string;
      readonly title: string;
      readonly note: string | null;
      readonly taskIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(
      `insert into app.missions (id, family_id, title, note, created_at, updated_at)
       values ($1, $2, $3, $4, $5, $5)`,
      [params.missionId, params.familyId, params.title, params.note, params.now],
    );
    await this.replaceTasks(tx, params.familyId, params.missionId, params.taskIds);
  }

  public async findMission(
    tx: TransactionContext,
    familyId: string,
    missionId: string,
    forUpdate = false,
  ): Promise<MissionRecord | undefined> {
    const client = asPostgresClient(tx);
    if (forUpdate) {
      await client.query(`select 1 from app.missions where family_id = $1 and id = $2 for update`, [
        familyId,
        missionId,
      ]);
    }
    const result = await client.query<MissionRow>(
      `select m.id, m.family_id, m.title, m.note, m.completed_at, m.created_at,
              coalesce(array_agg(mt.task_id::text order by mt.task_id)
                filter (where mt.task_id is not null), '{}') as task_ids
         from app.missions m
         left join app.mission_tasks mt on mt.family_id = m.family_id and mt.mission_id = m.id
        where m.family_id = $1 and m.id = $2
        group by m.id`,
      [familyId, missionId],
    );
    const row = result.rows[0];
    return row === undefined
      ? undefined
      : {
          id: row.id,
          familyId: row.family_id,
          title: row.title,
          note: row.note,
          completedAt: row.completed_at,
          createdAt: row.created_at,
          taskIds: row.task_ids ?? [],
        };
  }

  public async updateMission(
    tx: TransactionContext,
    params: {
      readonly mission: MissionRecord;
      readonly title: string;
      readonly note: string | null;
      readonly taskIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.missions set title = $3, note = $4, updated_at = $5
        where family_id = $1 and id = $2`,
      [params.mission.familyId, params.mission.id, params.title, params.note, params.now],
    );
    await this.replaceTasks(tx, params.mission.familyId, params.mission.id, params.taskIds);
  }

  public async listMissions(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly after?: PageCursor; readonly limit: number },
  ): Promise<readonly MissionSummaryRecord[]> {
    const result = await asPostgresClient(tx).query<MissionSummaryRow>(
      `select m.id, m.title, m.completed_at, m.created_at,
              count(t.id)::text as task_count,
              (count(t.id) filter (where t.status = 'completed'))::text as completed_task_count
         from app.missions m
         left join app.mission_tasks mt on mt.family_id = m.family_id and mt.mission_id = m.id
         left join app.task_occurrences t on t.family_id = mt.family_id and t.id = mt.task_id
        where m.family_id = $1
          and ($2::timestamptz is null or (m.created_at, m.id) < ($2::timestamptz, $3::uuid))
        group by m.id
        order by m.created_at desc, m.id desc
        limit $4`,
      [params.familyId, params.after?.sortKey ?? null, params.after?.id ?? null, params.limit],
    );
    return result.rows.map((row) => ({
      id: row.id,
      title: row.title,
      completedAt: row.completed_at,
      createdAt: row.created_at,
      taskCount: Number(row.task_count),
      completedTaskCount: Number(row.completed_task_count),
    }));
  }

  public async listTaskOptions(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly query?: string;
      readonly after?: PageCursor;
      readonly limit: number;
    },
  ): Promise<readonly MissionTaskOptionRecord[]> {
    const pattern = params.query === undefined ? null : `%${escapeLike(params.query)}%`;
    const result = await asPostgresClient(tx).query<TaskOptionRow>(
      `select t.id, t.title, t.weight, to_char(t.scheduled_date, 'YYYY-MM-DD') as scheduled_date,
              t.status,
              coalesce(array_agg(a.member_id::text order by a.member_id)
                filter (where a.member_id is not null), '{}') as assignee_ids
         from app.task_occurrences t
         left join app.task_assignees a on a.family_id = t.family_id and a.task_id = t.id
        where t.family_id = $1 and t.deleted_at is null
          and ($2::text is null or t.title ilike $2 escape '\\')
          and ($3::date is null or (t.scheduled_date, t.id) < ($3::date, $4::uuid))
        group by t.id
        order by t.scheduled_date desc, t.id desc
        limit $5`,
      [
        params.familyId,
        pattern,
        params.after?.sortKey ?? null,
        params.after?.id ?? null,
        params.limit,
      ],
    );
    return result.rows.map((row) => ({
      id: row.id,
      title: row.title,
      weight: row.weight,
      scheduledDate: row.scheduled_date,
      status: row.status,
      assigneeIds: row.assignee_ids ?? [],
    }));
  }

  public async findMissionIdsByTask(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<readonly string[]> {
    const result = await asPostgresClient(tx).query<{ mission_id: string }>(
      `select mission_id from app.mission_tasks where family_id = $1 and task_id = $2`,
      [familyId, taskId],
    );
    return result.rows.map((row) => row.mission_id);
  }

  public async closeEligible(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly missionIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<readonly ClosedMission[]> {
    const client = asPostgresClient(tx);
    const closed: ClosedMission[] = [];
    for (const missionId of params.missionIds) {
      // A condição `completed_at is null` sob o lock da família garante que
      // duas tentativas de fechamento nunca dupliquem participações (CA-16).
      const eligible = await client.query(
        `update app.missions m
            set completed_at = $3, updated_at = $3
          where m.family_id = $1 and m.id = $2 and m.completed_at is null
            and exists (
              select 1 from app.mission_tasks mt where mt.family_id = m.family_id and mt.mission_id = m.id
            )
            and not exists (
              select 1 from app.mission_tasks mt
                join app.task_occurrences t on t.family_id = mt.family_id and t.id = mt.task_id
               where mt.family_id = m.family_id and mt.mission_id = m.id and t.status <> 'completed'
            )
        returning m.id`,
        [params.familyId, missionId, params.now],
      );
      if ((eligible.rowCount ?? 0) === 0) {
        continue;
      }

      // Uma participação por pessoa com crédito vigente em ao menos uma tarefa.
      const participants = await client.query<{ member_id: string }>(
        `insert into app.mission_participations (family_id, mission_id, member_id, recorded_at)
         select distinct $1::uuid, $2::uuid, cc.member_id, $3::timestamptz
           from app.mission_tasks mt
           join app.completions c
             on c.family_id = mt.family_id and c.task_id = mt.task_id and c.undone_at is null
           join app.completion_credits cc on cc.completion_id = c.id
          where mt.family_id = $1 and mt.mission_id = $2
         returning member_id`,
        [params.familyId, missionId, params.now],
      );

      let badgesAwardedCount = 0;
      for (const { member_id: memberId } of participants.rows) {
        badgesAwardedCount += await this.awardReachedBadges(
          tx,
          params.familyId,
          memberId,
          params.now,
        );
      }
      closed.push({
        missionId,
        participationCount: participants.rowCount ?? 0,
        badgesAwardedCount,
      });
    }
    return closed;
  }

  /** Concede os marcos ainda não concedidos, retendo as N primeiras participações. */
  private async awardReachedBadges(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
    now: Date,
  ): Promise<number> {
    const client = asPostgresClient(tx);
    const reached = await client.query<{ code: string; min_missions: number }>(
      `select b.code, b.min_missions
         from app.badges b
        where b.min_missions <= (
                select count(*) from app.mission_participations p where p.member_id = $1
              )
          and not exists (
                select 1 from app.member_badges mb
                 where mb.member_id = $1 and mb.badge_code = b.code
              )
        order by b.min_missions`,
      [memberId],
    );
    for (const badge of reached.rows) {
      const memberBadgeId = randomUUID();
      await client.query(
        `insert into app.member_badges (id, family_id, member_id, badge_code, awarded_at)
         values ($1, $2, $3, $4, $5)`,
        [memberBadgeId, familyId, memberId, badge.code, now],
      );
      await client.query(
        `insert into app.badge_participations (member_badge_id, mission_id, member_id)
         select $1, p.mission_id, p.member_id
           from app.mission_participations p
          where p.member_id = $2
          order by p.recorded_at, p.mission_id
          limit $3`,
        [memberBadgeId, memberId, badge.min_missions],
      );
    }
    return reached.rows.length;
  }

  private async replaceTasks(
    tx: TransactionContext,
    familyId: string,
    missionId: string,
    taskIds: readonly string[],
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(`delete from app.mission_tasks where family_id = $1 and mission_id = $2`, [
      familyId,
      missionId,
    ]);
    await client.query(
      `insert into app.mission_tasks (family_id, mission_id, task_id)
       select $1, $2, unnest($3::uuid[])`,
      [familyId, missionId, taskIds],
    );
  }
}
