/**
 * Smoke de saúde operacional: exercita /health/live e /health/ready contra um
 * servidor HTTP real e um PostgreSQL real (sem mocks), como a CI faz após as
 * migrations. Fica desligado por padrão para que `npm run test` não dependa de
 * banco; use `npm run test:integration` (define RUN_INTEGRATION_TESTS).
 */
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { buildHttpApp } from '../../src/presentation/http/app.js';

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)('Operational health probes', () => {
  let container: ApplicationContainer;
  let app: FastifyInstance;
  let baseUrl: string;

  beforeAll(async () => {
    const config = loadConfiguration();
    container = createContainer(config);
    app = buildHttpApp(container, config);
    // Porta 0: o sistema escolhe uma porta livre, evitando colisão na CI.
    baseUrl = await app.listen({ port: 0, host: '127.0.0.1' });
  });

  afterAll(async () => {
    await app?.close();
    await container?.dispose();
  });

  it('GET /health/live reports the process as alive', async () => {
    const response = await fetch(`${baseUrl}/health/live`);

    expect(response.status).toBe(200);
    const body = (await response.json()) as { status: string; timestamp: string };
    expect(body.status).toBe('ok');
    expect(body.timestamp).toBeDefined();
  });

  it('GET /health/ready reports the database dependency as healthy', async () => {
    const response = await fetch(`${baseUrl}/health/ready`);

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      status: string;
      checks: { database: { status: string; latencyMs: number } };
    };
    expect(body.status).toBe('ready');
    expect(body.checks.database.status).toBe('healthy');
    expect(body.checks.database.latencyMs).toBeTypeOf('number');
  });
});
