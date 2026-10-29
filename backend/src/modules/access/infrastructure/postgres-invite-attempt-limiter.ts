import type { PostgresConnectionPool } from '../../../shared/infrastructure/postgres/connection-pool.js';
import type { InviteAttemptLimiterPort } from '../application/invite-attempt-limiter-port.js';

/**
 * Limite de tentativas em PostgreSQL (sem Redis). Usa uma transação própria,
 * fora da do ingresso: a tentativa precisa continuar registrada quando o
 * comando falha.
 *
 * O lock consultivo por identificador serializa as chamadas do mesmo sujeito.
 * Sem ele, uma rajada de requisições simultâneas leria a mesma contagem antes
 * de qualquer registro e passaria inteira pelo limite.
 */
export class PostgresInviteAttemptLimiter implements InviteAttemptLimiterPort {
  constructor(private readonly pool: PostgresConnectionPool) {}

  public async recordAndCheckExceeded(params: {
    readonly scope: 'invite' | 'origin';
    readonly subjectHash: string;
    readonly limit: number;
    readonly now: Date;
    readonly windowMs: number;
  }): Promise<boolean> {
    const windowStart = new Date(params.now.getTime() - params.windowMs);
    const client = await this.pool.getClient();

    try {
      await client.query('BEGIN');
      await client.query('select pg_advisory_xact_lock(hashtext($1))', [
        `invite-attempt:${params.scope}:${params.subjectHash}`,
      ]);
      // Linhas anteriores à janela saem aqui, sem job de limpeza próprio.
      await client.query(
        `delete from app.invite_attempt_log
          where scope = $1 and subject_hash = $2 and attempted_at < $3`,
        [params.scope, params.subjectHash, windowStart],
      );
      await client.query(
        `insert into app.invite_attempt_log (scope, subject_hash, attempted_at)
         values ($1, $2, $3)`,
        [params.scope, params.subjectHash, params.now],
      );
      const counted = await client.query<{ attempts: string }>(
        `select count(*)::text as attempts
           from app.invite_attempt_log
          where scope = $1 and subject_hash = $2 and attempted_at >= $3`,
        [params.scope, params.subjectHash, windowStart],
      );
      await client.query('COMMIT');

      return Number(counted.rows[0]?.attempts ?? '0') > params.limit;
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch {
        // o erro relevante é o original
      }
      throw error;
    } finally {
      client.release();
    }
  }
}
