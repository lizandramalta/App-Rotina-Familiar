import type { Configuration } from './configuration.js';
import { ConsoleLogger, type Logger } from '../shared/infrastructure/observability/logger.js';
import { SystemClock, type Clock } from '../shared/application/clock.js';
import { PostgresConnectionPool } from '../shared/infrastructure/postgres/connection-pool.js';

export interface ApplicationContainer {
  readonly config: Configuration;
  readonly logger: Logger;
  readonly clock: Clock;
  readonly dbPool: PostgresConnectionPool;
  dispose(): Promise<void>;
}

/**
 * Creates and initializes the top-level application dependency graph.
 */
export function createContainer(config: Configuration): ApplicationContainer {
  const logger = new ConsoleLogger(config.LOG_LEVEL, {
    service: 'backend',
    env: config.NODE_ENV,
  });

  const clock = new SystemClock();
  const dbPool = new PostgresConnectionPool(config, logger);

  return {
    config,
    logger,
    clock,
    dbPool,
    async dispose(): Promise<void> {
      logger.info('Disposing application container...');
      await dbPool.close();
      logger.info('Application container disposed.');
    },
  };
}
