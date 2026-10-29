/**
 * Container mínimo para exercitar a borda HTTP.
 *
 * Os casos de uso são dublês: o que está sob teste nas suítes de rota é o
 * contrato de transporte — validação, status, corpo e mapeamento de erro.
 */
import { vi } from 'vitest';
import { validateConfiguration, type Configuration } from '../../../src/bootstrap/configuration.js';
import { createAppleConfiguration } from '../../../src/integrations/apple/apple-configuration.js';
import type { ApplicationContainer } from '../../../src/bootstrap/container.js';
import { SystemClock } from '../../../src/shared/application/clock.js';
import { ConsoleLogger } from '../../../src/shared/infrastructure/observability/logger.js';

export interface HttpTestContainer {
  readonly container: ApplicationContainer;
  readonly config: Configuration;
  readonly signInWithApple: ReturnType<typeof vi.fn>;
  readonly getCurrentSession: ReturnType<typeof vi.fn>;
  readonly refreshSession: ReturnType<typeof vi.fn>;
  readonly revokeSession: ReturnType<typeof vi.fn>;
}

export function createHttpTestContainer(): HttpTestContainer {
  const config = validateConfiguration({
    NODE_ENV: 'test',
    DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres_test',
    LOG_LEVEL: 'fatal',
  });

  const signInWithApple = vi.fn();
  const getCurrentSession = vi.fn();
  const refreshSession = vi.fn();
  const revokeSession = vi.fn();

  const container = {
    config,
    logger: new ConsoleLogger('fatal'),
    clock: new SystemClock(),
    dbPool: { checkHealth: vi.fn() } as unknown as ApplicationContainer['dbPool'],
    appleConfig: createAppleConfiguration(config),
    appleTokenVerifier: {
      verifyIdentityProof: vi.fn(),
    } as unknown as ApplicationContainer['appleTokenVerifier'],
    accessRepository: {} as unknown as ApplicationContainer['accessRepository'],
    transactionRunner: {
      run: vi.fn(),
      forFamily: vi.fn(),
    } as unknown as ApplicationContainer['transactionRunner'],
    signInWithAppleUseCase: {
      execute: signInWithApple,
    } as unknown as ApplicationContainer['signInWithAppleUseCase'],
    getCurrentSessionUseCase: {
      execute: getCurrentSession,
    } as unknown as ApplicationContainer['getCurrentSessionUseCase'],
    refreshSessionUseCase: {
      execute: refreshSession,
    } as unknown as ApplicationContainer['refreshSessionUseCase'],
    revokeSessionUseCase: {
      execute: revokeSession,
    } as unknown as ApplicationContainer['revokeSessionUseCase'],
    dispose: vi.fn(),
  } as unknown as ApplicationContainer;

  return { container, config, signInWithApple, getCurrentSession, refreshSession, revokeSession };
}
