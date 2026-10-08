import type { Configuration } from './configuration.js';
import { ConsoleLogger, type Logger } from '../shared/infrastructure/observability/logger.js';
import { SystemClock, type Clock } from '../shared/application/clock.js';
import { PostgresConnectionPool } from '../shared/infrastructure/postgres/connection-pool.js';
import {
  createAppleConfiguration,
  type AppleConfiguration,
} from '../integrations/apple/apple-configuration.js';

export interface ApplicationContainer {
  readonly config: Configuration;
  readonly logger: Logger;
  readonly clock: Clock;
  readonly dbPool: PostgresConnectionPool;
  readonly appleConfig: AppleConfiguration;
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
  const appleConfig = createAppleConfiguration(config);

  return {
    config,
    logger,
    clock,
    dbPool,
    appleConfig,
    async dispose(): Promise<void> {
      logger.info('Disposing application container...');
      await dbPool.close();
      logger.info('Application container disposed.');
    },
  };
}
