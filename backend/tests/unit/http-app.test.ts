import { describe, it, expect, vi, beforeEach } from 'vitest';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import type { ApplicationContainer } from '../../src/bootstrap/container.js';
import type { Configuration } from '../../src/bootstrap/configuration.js';
import { SystemClock } from '../../src/shared/application/clock.js';
import { ConsoleLogger } from '../../src/shared/infrastructure/observability/logger.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';

describe('HTTP Presentation Layer (Fastify)', () => {
  let mockContainer: ApplicationContainer;
  let testConfig: Configuration;
  let mockDbCheckHealth: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    testConfig = {
      NODE_ENV: 'test',
      PORT: 3001,
      HOST: '127.0.0.1',
      API_BASE_URL: 'http://localhost:3001',
      LOG_LEVEL: 'fatal',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres_test',
      DATABASE_SCHEMA: 'app',
      DATABASE_POOL_MIN: 1,
      DATABASE_POOL_MAX: 2,
      DATABASE_SSL: false,
      SESSION_SECRET: 'test-session-secret-min-16-chars!',
      INVITE_ENVELOPE_KEY: 'test-invite-key-min-16-chars!',
    };

    mockDbCheckHealth = vi.fn().mockResolvedValue({ isHealthy: true, latencyMs: 2 });

    mockContainer = {
      config: testConfig,
      logger: new ConsoleLogger('fatal'),
      clock: new SystemClock(),
      dbPool: {
        checkHealth: mockDbCheckHealth,
        close: vi.fn(),
        getRawPool: vi.fn(),
        query: vi.fn(),
        getClient: vi.fn(),
      } as unknown as ApplicationContainer['dbPool'],
      dispose: vi.fn(),
    };
  });

  it('GET /health/live returns 200 and ok status', async () => {
    const app = buildHttpApp(mockContainer, testConfig);

    const response = await app.inject({
      method: 'GET',
      url: '/health/live',
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body.status).toBe('ok');
    expect(body.environment).toBe('test');
    expect(body.timestamp).toBeDefined();
  });

  it('GET /health/ready returns 200 when database is healthy', async () => {
    const app = buildHttpApp(mockContainer, testConfig);

    const response = await app.inject({
      method: 'GET',
      url: '/health/ready',
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body.status).toBe('ready');
    expect(body.checks.database.status).toBe('healthy');
  });

  it('GET /health/ready returns 503 when database is unhealthy', async () => {
    mockDbCheckHealth.mockResolvedValue({ isHealthy: false, error: 'Connection refused' });
    const app = buildHttpApp(mockContainer, testConfig);

    const response = await app.inject({
      method: 'GET',
      url: '/health/ready',
    });

    expect(response.statusCode).toBe(503);
    const body = JSON.parse(response.payload);
    expect(body.status).toBe('not_ready');
    expect(body.checks.database.status).toBe('unhealthy');
    expect(body.checks.database.error).toBe('Connection refused');
  });

  it('GET /v1 returns 200 and API metadata', async () => {
    const app = buildHttpApp(mockContainer, testConfig);

    const response = await app.inject({
      method: 'GET',
      url: '/v1',
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.payload);
    expect(body.name).toBe('App Rotina Familiar API');
    expect(body.version).toBe('0.1.0');
    expect(body.status).toBe('operational');
  });

  it('formats DomainError as RFC 9457 Problem Details', async () => {
    const app = buildHttpApp(mockContainer, testConfig);

    app.get('/test-domain-error', async () => {
      throw new NotFoundError('Family member was not found');
    });

    const response = await app.inject({
      method: 'GET',
      url: '/test-domain-error',
    });

    expect(response.statusCode).toBe(404);
    expect(response.headers['content-type']).toContain('application/problem+json');

    const body = JSON.parse(response.payload);
    expect(body.status).toBe(404);
    expect(body.code).toBe('RESOURCE_NOT_FOUND');
    expect(body.detail).toBe('Family member was not found');
    expect(body.requestId).toBeDefined();
    expect(body.type).toBe('https://api.rotinafamiliar.com/errors/resource-not-found');
  });

  it('formats generic unexpected errors as RFC 9457 Problem Details without leaking internals in production', async () => {
    const prodConfig = { ...testConfig, NODE_ENV: 'production' as const };
    const app = buildHttpApp(mockContainer, prodConfig);

    app.get('/test-fatal-error', async () => {
      throw new Error('Database connection credentials failed');
    });

    const response = await app.inject({
      method: 'GET',
      url: '/test-fatal-error',
    });

    expect(response.statusCode).toBe(500);
    expect(response.headers['content-type']).toContain('application/problem+json');

    const body = JSON.parse(response.payload);
    expect(body.status).toBe(500);
    expect(body.code).toBe('INTERNAL_SERVER_ERROR');
    expect(body.detail).toBe('An unexpected internal error occurred.');
    expect(body.detail).not.toContain('Database connection');
  });
});
