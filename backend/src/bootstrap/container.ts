import type { Configuration } from './configuration.js';
import { ConsoleLogger, type Logger } from '../shared/infrastructure/observability/logger.js';
import { SystemClock, type Clock } from '../shared/application/clock.js';
import { PostgresConnectionPool } from '../shared/infrastructure/postgres/connection-pool.js';
import {
  createAppleConfiguration,
  type AppleConfiguration,
} from '../integrations/apple/apple-configuration.js';
import { AppleJwksClient } from '../integrations/apple/apple-jwks-client.js';
import { AppleTokenVerifier } from '../integrations/apple/apple-token-verifier.js';
import { AppleTokenClient } from '../integrations/apple/apple-token-client.js';
import { PostgresTransactionRunner } from '../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { TransactionRunner } from '../shared/application/transaction-runner.js';
import { PostgresAccessRepository } from '../modules/access/infrastructure/postgres-access-repository.js';
import { CryptoTokenService } from '../modules/access/infrastructure/crypto-token-service.js';
import { SignInWithAppleUseCase } from '../modules/access/application/sign-in-with-apple-use-case.js';
import type { AccessRepositoryPort } from '../modules/access/application/access-repository-port.js';
import type { AppleTokenVerifierPort } from '../integrations/apple/apple-token-verifier-port.js';

export interface ApplicationContainer {
  readonly config: Configuration;
  readonly logger: Logger;
  readonly clock: Clock;
  readonly dbPool: PostgresConnectionPool;
  readonly appleConfig: AppleConfiguration;
  readonly appleTokenVerifier: AppleTokenVerifierPort;
  readonly accessRepository: AccessRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly signInWithAppleUseCase: SignInWithAppleUseCase;
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
  const transactionRunner = new PostgresTransactionRunner(dbPool);

  const appleTokenVerifier = new AppleTokenVerifier(
    appleConfig,
    new AppleJwksClient(appleConfig, logger),
    new AppleTokenClient(appleConfig, logger),
  );

  const accessRepository = new PostgresAccessRepository();

  const signInWithAppleUseCase = new SignInWithAppleUseCase({
    repository: accessRepository,
    tokenVerifier: appleTokenVerifier,
    crypto: new CryptoTokenService(config.SESSION_SECRET),
    transactionRunner,
    clock,
    logger,
  });

  return {
    config,
    logger,
    clock,
    dbPool,
    appleConfig,
    appleTokenVerifier,
    accessRepository,
    transactionRunner,
    signInWithAppleUseCase,
    async dispose(): Promise<void> {
      logger.info('Disposing application container...');
      await dbPool.close();
      logger.info('Application container disposed.');
    },
  };
}
