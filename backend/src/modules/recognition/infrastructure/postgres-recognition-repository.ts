import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import { SessionExpiredError } from '../../access/domain/access-errors.js';
import type {
  RecognitionCycle,
  RecognitionRepositoryPort,
  WeeklyRecognitionView,
} from '../application/recognition-repository-port.js';
import type { WeeklyScore } from '../domain/weekly-winners.js';

interface CycleRow {
  id: string;
  starts_at: Date;
  ends_at: Date;
  time_zone: string;
  reference_week: string;
  is_transition: boolean;
}
interface RecognitionRow extends CycleRow {
  points: number;
  completed_tasks: number;
  winner_count: number;
  processed_at: Date;
  opened_at: Date | null;
}
const ownProjection = `select r.id, r.points, r.completed_tasks, r.opened_at,
  h.starts_at, h.ends_at, h.time_zone, h.reference_week::text,
  h.is_transition, h.processed_at, h.winner_count
  from app.weekly_recognitions r
  join app.weekly_highlights h on h.id = r.highlight_id and h.family_id = r.family_id
  where r.family_id = $1 and r.member_id = $2`;

function toView(row: RecognitionRow): WeeklyRecognitionView {
  return {
    id: row.id,
    period: {
      startsAt: row.starts_at.toISOString(),
      endsAt: row.ends_at.toISOString(),
      referenceWeek: row.reference_week,
    },
    timeZoneId: row.time_zone,
    isTransition: row.is_transition,
    points: row.points,
    completedTasks: row.completed_tasks,
    isTie: row.winner_count > 1,
    processedAt: row.processed_at.toISOString(),
    openedAt: row.opened_at?.toISOString() ?? null,
  };
}

export class PostgresRecognitionRepository implements RecognitionRepositoryPort {
  async now(tx: TransactionContext): Promise<Date> {
    const result = await asPostgresClient(tx).query<{ now: Date }>(
      'select clock_timestamp() as now',
    );
    return result.rows[0]!.now;
  }

  async findUnfinalizedCycles(
    tx: TransactionContext,
    familyId: string,
    now: Date,
  ): Promise<readonly RecognitionCycle[]> {
    const result = await asPostgresClient(tx).query<CycleRow>(
      `select c.id, c.starts_at, c.ends_at, c.time_zone, c.reference_week::text, c.in_transition as is_transition
       from app.weekly_cycles c where c.family_id = $1 and c.ends_at <= $2
       and not exists (select 1 from app.weekly_highlights h where h.cycle_id = c.id)
       order by c.starts_at`,
      [familyId, now],
    );
    return result.rows.map((r) => ({
      id: r.id,
      startsAt: r.starts_at,
      endsAt: r.ends_at,
      timeZoneId: r.time_zone,
      referenceWeek: r.reference_week,
      isTransition: r.is_transition,
    }));
  }

  async scores(
    tx: TransactionContext,
    familyId: string,
    cycle: RecognitionCycle,
  ): Promise<readonly WeeklyScore[]> {
    const result = await asPostgresClient(tx).query<{
      member_id: string;
      points: number;
      completed_tasks: number;
    }>(
      `select c.member_id, sum(c.weight)::integer as points, count(distinct done.task_id)::integer as completed_tasks
       from app.completion_credits c
       join app.completions done on done.id = c.completion_id and done.family_id = c.family_id
       join app.members m on m.id = c.member_id and m.family_id = c.family_id and m.removed_at is null
       where c.family_id = $1 and done.undone_at is null
       and done.completed_at >= $2 and done.completed_at < $3
       group by c.member_id order by c.member_id`,
      [familyId, cycle.startsAt, cycle.endsAt],
    );
    return result.rows.map((r) => ({
      memberId: r.member_id,
      points: r.points,
      completedTasks: r.completed_tasks,
    }));
  }

  async saveFinalResult(
    tx: TransactionContext,
    familyId: string,
    cycle: RecognitionCycle,
    winners: readonly WeeklyScore[],
    processedAt: Date,
  ): Promise<void> {
    const db = asPostgresClient(tx);
    const highlightId = randomUUID();
    await db.query(
      `insert into app.weekly_highlights
      (id, family_id, cycle_id, starts_at, ends_at, time_zone, reference_week, is_transition, processed_at, winner_count)
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        highlightId,
        familyId,
        cycle.id,
        cycle.startsAt,
        cycle.endsAt,
        cycle.timeZoneId,
        cycle.referenceWeek,
        cycle.isTransition,
        processedAt,
        winners.length,
      ],
    );
    for (const winner of winners) {
      const id = randomUUID();
      await db.query(
        `insert into app.weekly_recognitions
        (id, family_id, highlight_id, member_id, points, completed_tasks) values ($1,$2,$3,$4,$5,$6)`,
        [id, familyId, highlightId, winner.memberId, winner.points, winner.completedTasks],
      );
      await db.query(
        'insert into app.recognition_notification_deliveries (recognition_id) values ($1)',
        [id],
      );
    }
  }

  async requireActiveSession(tx: TransactionContext, actor: ActorContext): Promise<void> {
    const result = await asPostgresClient(tx).query(
      `select s.id from app.sessions s join app.members m on m.id = s.member_id and m.family_id = s.family_id
       where s.id = $1 and s.family_id = $2 and s.member_id = $3 and s.revoked_at is null and m.removed_at is null`,
      [actor.sessionId, actor.familyId, actor.memberId],
    );
    if (!result.rowCount) throw new SessionExpiredError();
  }

  async listOwn(tx: TransactionContext, actor: ActorContext) {
    const result = await asPostgresClient(tx).query<RecognitionRow>(
      `${ownProjection} order by h.ends_at desc, r.id`,
      [actor.familyId, actor.memberId],
    );
    return result.rows.map(toView);
  }
  async findOwn(tx: TransactionContext, actor: ActorContext, id: string) {
    const result = await asPostgresClient(tx).query<RecognitionRow>(
      `${ownProjection} and r.id = $3`,
      [actor.familyId, actor.memberId, id],
    );
    return result.rows[0] ? toView(result.rows[0]) : undefined;
  }
  async openOwn(tx: TransactionContext, actor: ActorContext, id: string): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.weekly_recognitions set opened_at = coalesce(opened_at, clock_timestamp())
       where family_id = $1 and member_id = $2 and id = $3`,
      [actor.familyId, actor.memberId, id],
    );
  }
}
