import type pg from 'pg';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../application/transaction-runner.js';
import type { PostgresConnectionPool } from './connection-pool.js';

/**
 * Contexto de transação concreto. O caso de uso recebe `TransactionContext`, que
 * expõe `client` como `unknown`; só os repositórios de Infrastructure estreitam
 * para `pg.PoolClient`.
 */
export interface PostgresTransactionContext extends TransactionContext {
  readonly client: pg.PoolClient;
}

/**
 * Estreita o contexto na borda do repositório. Falhar alto aqui é melhor do que
 * deixar um `as` silencioso espalhado por cada query.
 */
export function asPostgresClient(tx: TransactionContext): pg.PoolClient {
  const client = tx.client;

  if (client === null || typeof client !== 'object' || !('query' in client)) {
    throw new TypeError('TransactionContext does not carry a PostgreSQL client.');
  }

  return client as pg.PoolClient;
}

export class PostgresTransactionRunner implements TransactionRunner {
  constructor(private readonly pool: PostgresConnectionPool) {}

  public async run<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T> {
    const client = await this.pool.getClient();

    try {
      await client.query('BEGIN');
      const result = await work({ client });
      await client.query('COMMIT');
      return result;
    } catch (error) {
      // O ROLLBACK não pode mascarar o erro original: se ele próprio falhar
      // (conexão já perdida), a causa real é a que precisa subir.
      try {
        await client.query('ROLLBACK');
      } catch {
        // intencionalmente ignorado; o erro relevante é relançado abaixo
      }
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Serializa escritas curtas da mesma família (BA-08). O lock é por família e
   * vive até o fim da transação.
   */
  public async forFamily<T>(
    familyId: string,
    work: (tx: TransactionContext) => Promise<T>,
  ): Promise<T> {
    return this.run(async (tx) => {
      const client = asPostgresClient(tx);
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [familyId]);
      return work(tx);
    });
  }
}
