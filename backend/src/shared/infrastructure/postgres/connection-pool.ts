import pg from 'pg';
import type { Configuration } from '../../../bootstrap/configuration.js';
import type { Logger } from '../observability/logger.js';

export interface DatabaseHealthResult {
  isHealthy: boolean;
  latencyMs?: number;
  error?: string;
}

export class PostgresConnectionPool {
  private readonly pool: pg.Pool;
  private readonly logger: Logger;
  private readonly schema: string;

  constructor(config: Configuration, logger: Logger) {
    this.logger = logger.child({ component: 'PostgresConnectionPool' });
    this.schema = config.DATABASE_SCHEMA;

    const ssl = config.DATABASE_SSL ? { rejectUnauthorized: false } : false;

    this.pool = new pg.Pool({
      connectionString: config.DATABASE_URL,
      min: config.DATABASE_POOL_MIN,
      max: config.DATABASE_POOL_MAX,
      ssl,
    });

    this.pool.on('error', (err) => {
      this.logger.error('Unexpected error on idle PostgreSQL client in pool', err);
    });

    // Ensure search_path defaults to configured schema (BA-19: schema 'app')
    this.pool.on('connect', (client) => {
      client.query(`SET search_path TO "${this.schema}", public`).catch((err) => {
        this.logger.error('Failed to set search_path on new database client', err);
      });
    });
  }

  public getRawPool(): pg.Pool {
    return this.pool;
  }

  public async query<T extends pg.QueryResultRow = pg.QueryResultRow>(
    text: string,
    params?: unknown[],
  ): Promise<pg.QueryResult<T>> {
    return this.pool.query<T>(text, params);
  }

  public async getClient(): Promise<pg.PoolClient> {
    return this.pool.connect();
  }

  public async checkHealth(): Promise<DatabaseHealthResult> {
    const start = Date.now();
    try {
      await this.pool.query('SELECT 1 AS health_check');
      const latencyMs = Date.now() - start;
      return { isHealthy: true, latencyMs };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.warn('Database health check query failed', { error: message });
      return { isHealthy: false, error: message };
    }
  }

  public async close(): Promise<void> {
    this.logger.info('Closing PostgreSQL connection pool...');
    await this.pool.end();
    this.logger.info('PostgreSQL connection pool closed.');
  }
}
