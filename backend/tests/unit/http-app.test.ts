import { describe, it, expect, vi, beforeEach } from 'vitest';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import type { ApplicationContainer } from '../../src/bootstrap/container.js';
import { validateConfiguration, type Configuration } from '../../src/bootstrap/configuration.js';
import { createAppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';
import { SystemClock } from '../../src/shared/application/clock.js';
import { ConsoleLogger } from '../../src/shared/infrastructure/observability/logger.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';

describe('HTTP Presentation Layer (Fastify)', () => {
  let mockContainer: ApplicationContainer;
  let testConfig: Configuration;
  let mockDbCheckHealth: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    // Derivar do schema em vez de montar o objeto na mão: novos campos de
    // configuração ganham default sem quebrar esta fixture.
    testConfig = validateConfiguration({
      NODE_ENV: 'test',
      PORT: 3001,
      HOST: '127.0.0.1',
      API_BASE_URL: 'http://localhost:3001',
      LOG_LEVEL: 'fatal',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres_test',
      DATABASE_SCHEMA: 'app',
      DATABASE_POOL_MIN: 1,
      DATABASE_POOL_MAX: 2,
      SESSION_SECRET: 'test-session-secret-min-16-chars!',
      INVITE_ENVELOPE_KEY: 'test-invite-key-min-16-chars!',
    });

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
      appleConfig: createAppleConfiguration(testConfig),
      // Dependências do módulo Access: estes testes exercitam só as rotas
      // operacionais, então stubs bastam. access-routes.test.ts cobre a rota.
      appleTokenVerifier: {
        verifyIdentityProof: vi.fn(),
      } as unknown as ApplicationContainer['appleTokenVerifier'],
      accessRepository: {} as unknown as ApplicationContainer['accessRepository'],
      transactionRunner: {
        run: vi.fn(),
        forFamily: vi.fn(),
      } as unknown as ApplicationContainer['transactionRunner'],
      signInWithAppleUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['signInWithAppleUseCase'],
      getCurrentSessionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getCurrentSessionUseCase'],
      refreshSessionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['refreshSessionUseCase'],
      revokeSessionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['revokeSessionUseCase'],
      authenticateSessionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['authenticateSessionUseCase'],
      inspectInviteUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['inspectInviteUseCase'],
      joinFamilyByInviteUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['joinFamilyByInviteUseCase'],
      recoverInviteJoinUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['recoverInviteJoinUseCase'],
      createFamilyUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['createFamilyUseCase'],
      getFamilyUseCase: { execute: vi.fn() } as unknown as ApplicationContainer['getFamilyUseCase'],
      updateFamilyUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['updateFamilyUseCase'],
      getFamilySettingsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getFamilySettingsUseCase'],
      previewFamilyTimeZoneChangeUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['previewFamilyTimeZoneChangeUseCase'],
      changeFamilyTimeZoneUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['changeFamilyTimeZoneUseCase'],
      listFamilyMembersUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['listFamilyMembersUseCase'],
      getMemberDetailUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getMemberDetailUseCase'],
      createMemberUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['createMemberUseCase'],
      updateMemberUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['updateMemberUseCase'],
      changeMemberRoleUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['changeMemberRoleUseCase'],
      leaveAdministrationUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['leaveAdministrationUseCase'],
      removeMemberUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['removeMemberUseCase'],
      issueMemberInviteUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['issueMemberInviteUseCase'],
      uploadMediaUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['uploadMediaUseCase'],
      uploadOnboardingMediaUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['uploadOnboardingMediaUseCase'],
      getMediaContentUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getMediaContentUseCase'],
      cleanOrphanOnboardingMedia: {
        run: vi.fn(),
      } as unknown as ApplicationContainer['cleanOrphanOnboardingMedia'],
      updateOwnProfileUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['updateOwnProfileUseCase'],
      getOwnProfileUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getOwnProfileUseCase'],
      getOwnBadgesUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getOwnBadgesUseCase'],
      getBadgeContributionsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getBadgeContributionsUseCase'],
      createTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['createTaskUseCase'],
      completeTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['completeTaskUseCase'],
      reopenTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['reopenTaskUseCase'],
      getTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getTaskUseCase'],
      getOwnTasksUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getOwnTasksUseCase'],
      getOwnProgressUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getOwnProgressUseCase'],
      getFamilyOverviewUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getFamilyOverviewUseCase'],
      getFamilyTasksUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getFamilyTasksUseCase'],
      getWeeklyReportSnapshotUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getWeeklyReportSnapshotUseCase'],
      signalTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['signalTaskUseCase'],
      listKidsSignalsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['listKidsSignalsUseCase'],
      getKidsSignalUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getKidsSignalUseCase'],
      decideKidsSignalUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['decideKidsSignalUseCase'],
      editTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['editTaskUseCase'],
      deleteTaskUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['deleteTaskUseCase'],
      createRoutineUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['createRoutineUseCase'],
      getRoutineUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getRoutineUseCase'],
      updateFutureRoutineUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['updateFutureRoutineUseCase'],
      deleteFutureRoutineTasksUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['deleteFutureRoutineTasksUseCase'],
      createMissionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['createMissionUseCase'],
      editMissionUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['editMissionUseCase'],
      listMissionsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['listMissionsUseCase'],
      getMissionDetailUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getMissionDetailUseCase'],
      getMissionTaskOptionsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['getMissionTaskOptionsUseCase'],
      listRewardItemsUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['listRewardItemsUseCase'],
      addRewardItemUseCase: {
        execute: vi.fn(),
      } as unknown as ApplicationContainer['addRewardItemUseCase'],
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
    expect(body.name).toBe('Mutua API');
    expect(body.version).toBe('0.1.0');
    expect(body.status).toBe('operational');
  });

  it('serves Swagger UI and an OpenAPI document for every implemented API area', async () => {
    const app = buildHttpApp(mockContainer, testConfig);

    const ui = await app.inject({ method: 'GET', url: '/docs' });
    expect(ui.statusCode).toBe(200);
    expect(ui.headers['content-type']).toContain('text/html');

    const specResponse = await app.inject({ method: 'GET', url: '/docs/json' });
    expect(specResponse.statusCode).toBe(200);

    const spec = specResponse.json() as {
      openapi: string;
      info: { title: string };
      paths: Record<string, Record<string, { security?: unknown[] }>>;
      components: { securitySchemes: Record<string, { scheme: string }> };
    };
    expect(spec.openapi).toBe('3.1.0');
    expect(spec.info.title).toBe('Mutua API');
    expect(Object.keys(spec.paths)).toEqual(
      expect.arrayContaining([
        '/health/live',
        '/health/ready',
        '/v1/access/apple',
        '/v1/families',
        '/v1/family/members',
        '/v1/family/members/{memberId}',
        '/v1/family/members/{memberId}/role-changes',
        '/v1/me/administration-exit',
        '/v1/family/overview',
        '/v1/family/tasks',
        '/v1/family/members/{memberId}/tasks',
        '/v1/tasks/{taskId}/signals',
        '/v1/kids/signals',
        '/v1/kids/signals/{signalId}',
        '/v1/kids/signals/{signalId}/decision',
        '/v1/reports/weekly-snapshot',
        '/v1/media',
        '/v1/me/profile',
        '/v1/tasks',
        '/v1/tasks/{taskId}',
      ]),
    );
    expect(spec.components.securitySchemes.bearerAuth).toMatchObject({ scheme: 'bearer' });
    for (const path of [
      '/v1/family/overview',
      '/v1/family/tasks',
      '/v1/tasks/{taskId}/signals',
      '/v1/kids/signals',
      '/v1/reports/weekly-snapshot',
    ]) {
      const operations = Object.values(spec.paths[path] ?? {});
      expect(operations[0]?.security).toEqual([{ bearerAuth: [] }]);
    }

    await app.close();
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
