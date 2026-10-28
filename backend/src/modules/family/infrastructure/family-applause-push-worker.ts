import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import { ApnsPushGateway } from '../../../integrations/apple/apns-push-gateway.js';

interface Job {
  id: string;
  applause_id: string;
  push_device_id: string;
  device_token: string;
  environment: string;
  sender_name: string;
  attempts: number;
}

export class FamilyApplausePushWorker {
  constructor(
    private readonly db: PostgresConnectionPool,
    private readonly gateway: ApnsPushGateway,
  ) {}

  async run(): Promise<void> {
    const client = await this.db.getClient();
    try {
      await client.query('begin');
      await client.query(
        `update app.family_applause_push_outbox o
         set state = 'failed', last_error = 'DEVICE_REVOKED'
         from app.push_devices d join app.sessions s on s.id = d.session_id
         where o.push_device_id = d.id and o.state = 'pending'
           and (d.revoked_at is not null or s.revoked_at is not null)`,
      );
      const jobs = await client.query<Job>(
        `select o.id, o.applause_id, o.push_device_id, d.device_token, d.environment,
                coalesce(m.display_name, 'Alguém') as sender_name, o.attempts
         from app.family_applause_push_outbox o
         join app.family_applause a on a.id = o.applause_id
         join app.members m on m.id = a.sender_member_id and m.family_id = a.family_id
         join app.members recipient on recipient.id = a.recipient_member_id
              and recipient.family_id = a.family_id and recipient.removed_at is null
         join app.push_devices d on d.id = o.push_device_id
         join app.sessions s on s.id = d.session_id
         where o.state = 'pending' and o.next_attempt_at <= now()
           and d.revoked_at is null and s.revoked_at is null and s.member_id = recipient.id
         order by o.next_attempt_at, o.id limit 10 for update of o skip locked`,
      );
      for (const job of jobs.rows) {
        let status: number;
        try {
          status = await this.gateway.send(
            job.device_token,
            job.environment,
            job.applause_id,
            job.sender_name,
          );
        } catch {
          status = 503;
        }
        if (status === 200) {
          await client.query(
            `update app.family_applause_push_outbox set state = 'acceptedByProvider', accepted_at = now(), attempts = attempts + 1, last_error = null where id = $1`,
            [job.id],
          );
        } else {
          const terminal = status === 410 || status === 400 || job.attempts >= 4;
          await client.query(
            `update app.family_applause_push_outbox set state = $2, attempts = attempts + 1,
             next_attempt_at = now() + (power(2, least(attempts, 6)) * interval '1 minute'), last_error = $3 where id = $1`,
            [job.id, terminal ? 'failed' : 'pending', `HTTP ${status}`],
          );
          if (status === 410)
            await client.query(`update app.push_devices set revoked_at = now() where id = $1`, [
              job.push_device_id,
            ]);
        }
      }
      await client.query('commit');
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  }
}
