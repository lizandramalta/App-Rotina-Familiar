import { randomUUID } from 'node:crypto';
import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import type { RecognitionPushPort } from '../application/recognition-push-port.js';

interface Delivery {
  recognition_id: string;
  attempts: number;
}
interface Device {
  id: string;
  device_token: string;
  environment: string;
}

/** SPEC-020 CA-03/06: claim confirmado antes do I/O; resposta só vale para seu claim. */
export class RecognitionPushWorker {
  constructor(
    private readonly db: PostgresConnectionPool,
    private readonly gateway: RecognitionPushPort,
    private readonly environment: 'development' | 'production',
    private readonly maxAttempts = 5,
  ) {}

  async run(): Promise<void> {
    // Um processo pode morrer depois de consumir a última tentativa e antes de salvar a resposta.
    await this.db.query(
      `update app.recognition_notification_deliveries
      set state = 'failed', lease_until = null, claim_id = null, last_error = 'RETRY_LIMIT_REACHED'
      where state = 'pending' and attempts >= $1
      and (lease_until is null or lease_until <= statement_timestamp())`,
      [this.maxAttempts],
    );
    for (let index = 0; index < 20; index++) {
      const claim = randomUUID();
      const result = await this.db.query<Delivery>(
        `update app.recognition_notification_deliveries set claim_id = $1,
         lease_until = statement_timestamp() + interval '1 minute'
         where recognition_id = (select recognition_id from app.recognition_notification_deliveries
           where state = 'pending' and available_at <= statement_timestamp()
           and (lease_until is null or lease_until <= statement_timestamp())
           order by available_at, recognition_id limit 1 for update skip locked)
         returning recognition_id, attempts`,
        [claim],
      );
      const job = result.rows[0];
      if (!job) break;
      // Revalida sessão, membro, token e ambiente imediatamente antes do envio.
      const devices = await this.db.query<Device>(
        `select d.id, d.device_token, d.environment from app.weekly_recognitions r
         join app.members m on m.id = r.member_id and m.family_id = r.family_id and m.removed_at is null
         join app.sessions s on s.member_id = m.id and s.family_id = m.family_id and s.revoked_at is null
         join app.push_devices d on d.session_id = s.id and d.revoked_at is null
         where r.id = $1 and d.environment = $2 order by d.updated_at desc, d.id limit 1`,
        [job.recognition_id, this.environment],
      );
      const device = devices.rows[0];
      if (!device) {
        // Não consumir tentativas de envio quando ainda não existe aparelho autorizado.
        await this.db.query(
          `update app.recognition_notification_deliveries
          set claim_id = null, lease_until = null, available_at = statement_timestamp() + interval '15 minutes', last_error = 'NO_ACTIVE_DEVICE'
          where recognition_id = $1 and claim_id = $2`,
          [job.recognition_id, claim],
        );
        continue;
      }
      const attempt = await this.db.query(
        `update app.recognition_notification_deliveries set attempts = attempts + 1
        where recognition_id = $1 and claim_id = $2 and lease_until > statement_timestamp() returning recognition_id`,
        [job.recognition_id, claim],
      );
      if (!attempt.rowCount) continue;
      let status: number;
      try {
        status = await this.gateway.sendRecognition(
          device.device_token,
          device.environment,
          job.recognition_id,
        );
      } catch {
        status = 503;
      }
      // Uma transação curta confirma aceitação/falha e revoga o token inválido.
      const client = await this.db.getClient();
      try {
        await client.query('begin');
        const terminal = status === 400 || status === 410 || job.attempts + 1 >= this.maxAttempts;
        const updated = await client.query(
          `update app.recognition_notification_deliveries
          set state = $3, accepted_at = case when $3 = 'acceptedByProvider' then statement_timestamp() else null end,
          lease_until = null, claim_id = null, last_error = $4,
          available_at = statement_timestamp() + (power(2, least(attempts, 6)) + random()) * interval '1 minute'
          where recognition_id = $1 and claim_id = $2 returning recognition_id`,
          [
            job.recognition_id,
            claim,
            status === 200 ? 'acceptedByProvider' : terminal ? 'failed' : 'pending',
            status === 200 ? null : `HTTP_${status}`,
          ],
        );
        if (updated.rowCount && status === 410) {
          await client.query(
            `update app.push_devices set revoked_at = statement_timestamp()
            where id = $1 and device_token = $2`,
            [device.id, device.device_token],
          );
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
}
