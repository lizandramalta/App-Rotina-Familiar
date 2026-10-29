import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { WeeklyReportRepositoryPort } from '../application/weekly-report-repository-port.js';

export class PostgresWeeklyReportRepository implements WeeklyReportRepositoryPort {
  async findRole(tx: TransactionContext, familyId: string, memberId: string) {
    const result = await asPostgresClient(tx).query<{ role: string }>(
      'select role from app.members where family_id = $1 and id = $2 and removed_at is null',
      [familyId, memberId],
    );
    return result.rows[0]?.role;
  }

  async findFamily(tx: TransactionContext, familyId: string) {
    const result = await asPostgresClient(tx).query<{ timezone: string; created_at: Date }>(
      'select timezone, created_at from app.families where id = $1',
      [familyId],
    );
    const row = result.rows[0];
    return row ? { timeZoneId: row.timezone, createdAt: row.created_at } : undefined;
  }

  async getSnapshot(
    tx: TransactionContext,
    params: { familyId: string; startDate: string; endDate: string },
  ) {
    // One statement provides an MVCC-consistent snapshot for tasks, credits and members.
    const result = await asPostgresClient(tx).query<{
      total_tasks: number;
      completed_tasks: number;
      is_transition: boolean;
      members: {
        memberId: string | null;
        displayName: string;
        weight: number;
        completedTasks: number;
      }[];
    }>(
      `with progress as (
         select count(*)::int as total_tasks,
                count(*) filter (where status = 'completed')::int as completed_tasks
           from app.task_occurrences
          where family_id = $1 and scheduled_date between $2::date and $3::date
            and deleted_at is null
       ), credits as (
         select c.member_id, sum(c.weight)::int as weight, count(*)::int as completed_tasks
           from app.completion_credits c
           join app.completions done on done.id = c.completion_id
          where c.family_id = $1 and done.family_id = $1 and done.undone_at is null
            and (done.completed_at at time zone (select timezone from app.families where id = $1))::date
                between $2::date and $3::date
          group by c.member_id
       )
       select p.total_tasks, p.completed_tasks,
              exists(select 1 from app.family_time_zone_changes z
                     where z.family_id = $1 and (z.effective_at at time zone (select timezone from app.families where id = $1))::date between $2::date and $3::date
                       and z.status = 'APPLIED') as is_transition,
              coalesce((select jsonb_agg(jsonb_build_object(
                'memberId', case when m.removed_at is null then m.id else null end,
                'displayName', case when m.removed_at is null then coalesce(m.display_name, '') else 'Membro removido' end,
                'weight', coalesce(c.weight, 0),
                'completedTasks', coalesce(c.completed_tasks, 0)
              ) order by m.created_at, m.id)
                from app.members m left join credits c on c.member_id = m.id
               where m.family_id = $1 and (m.removed_at is null or c.member_id is not null)), '[]'::jsonb) as members
         from progress p`,
      [params.familyId, params.startDate, params.endDate],
    );
    const row = result.rows[0];
    if (!row) throw new Error('Weekly report snapshot query returned no row.');
    return {
      totalTasks: row.total_tasks,
      completedTasks: row.completed_tasks,
      isTransition: row.is_transition,
      members: row.members,
    };
  }
}
