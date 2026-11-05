import { randomUUID } from 'node:crypto';
import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { FinalizeWeeklyHighlight } from '../application/finalize-weekly-highlight.js';

/** SPEC-020 CA-01/03: descoberta pelo relógio PostgreSQL e claim recuperável. */
export class WeeklyHighlightWorker {
  constructor(
    private readonly db: PostgresConnectionPool,
    private readonly finalizer: Pick<FinalizeWeeklyHighlight, 'execute'>,
    private readonly logger: Logger,
    private readonly maxAttempts = 10,
  ) {}

  async run(): Promise<void> {
    await this.db.query(
      `update app.weekly_highlight_jobs
      set state = 'failed', lease_until = null, claim_id = null, last_error = 'RETRY_LIMIT_REACHED'
      where state = 'pending' and attempts >= $1
      and (lease_until is null or lease_until <= statement_timestamp())`,
      [this.maxAttempts],
    );
    await this.db.query(`insert into app.weekly_highlight_jobs (family_id, available_at)
      select c.family_id, min(c.ends_at) from app.weekly_cycles c
      where c.ends_at <= statement_timestamp()
      and not exists (select 1 from app.weekly_highlights h where h.cycle_id = c.id)
      group by c.family_id
      on conflict (family_id) do nothing`);
    for (let index = 0; index < 20; index++) {
      const claim = randomUUID();
      const result = await this.db.query<{ family_id: string; attempts: number }>(
        `update app.weekly_highlight_jobs set claim_id = $1, lease_until = statement_timestamp() + interval '5 minutes', attempts = attempts + 1
         where family_id = (select family_id from app.weekly_highlight_jobs
         where state = 'pending' and available_at <= statement_timestamp()
         and (lease_until is null or lease_until <= statement_timestamp())
         order by available_at, family_id limit 1 for update skip locked)
         returning family_id, attempts`,
        [claim],
      );
      const job = result.rows[0];
      if (!job) break;
      const started = Date.now();
      try {
        const cycles = await this.finalizer.execute(job.family_id);
        await this.db.query(
          'delete from app.weekly_highlight_jobs where family_id = $1 and claim_id = $2',
          [job.family_id, claim],
        );
        this.logger.info('weekly_highlight_finalized', {
          familyId: job.family_id,
          cycles,
          durationMs: Date.now() - started,
        });
      } catch {
        await this.db.query(
          `update app.weekly_highlight_jobs set state = $3, lease_until = null, claim_id = null,
          available_at = statement_timestamp() + (power(2, least(attempts, 6)) + random()) * interval '1 minute',
          last_error = 'FINALIZATION_FAILED' where family_id = $1 and claim_id = $2`,
          [job.family_id, claim, job.attempts >= this.maxAttempts ? 'failed' : 'pending'],
        );
        this.logger.warn('weekly_highlight_retry', {
          familyId: job.family_id,
          attempts: job.attempts,
        });
      }
    }
  }
}
