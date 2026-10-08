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
import { GetCurrentSessionUseCase } from '../modules/access/application/get-current-session-use-case.js';
import { RefreshSessionUseCase } from '../modules/access/application/refresh-session-use-case.js';
import { RevokeSessionUseCase } from '../modules/access/application/revoke-session-use-case.js';
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
  readonly getCurrentSessionUseCase: GetCurrentSessionUseCase;
  readonly refreshSessionUseCase: RefreshSessionUseCase;
  readonly revokeSessionUseCase: RevokeSessionUseCase;
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
  // Uma instância só: a chave AES vem de uma derivação scrypt, que é custosa.
  const accessCrypto = new CryptoTokenService(config.SESSION_SECRET);

  const signInWithAppleUseCase = new SignInWithAppleUseCase({
    repository: accessRepository,
    tokenVerifier: appleTokenVerifier,
    crypto: accessCrypto,
    transactionRunner,
    clock,
    logger,
  });

  const getCurrentSessionUseCase = new GetCurrentSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
  });

  const refreshSessionUseCase = new RefreshSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
    transactionRunner,
    clock,
  });

  const revokeSessionUseCase = new RevokeSessionUseCase({
    repository: accessRepository,
    crypto: accessCrypto,
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
    getCurrentSessionUseCase,
    refreshSessionUseCase,
    revokeSessionUseCase,
    async dispose(): Promise<void> {
      logger.info('Disposing application container...');
      await dbPool.close();
      logger.info('Application container disposed.');
    },
  };
}
