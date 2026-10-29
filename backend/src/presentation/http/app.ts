import Fastify, { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { randomUUID } from 'node:crypto';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import type { Configuration } from '../../bootstrap/configuration.js';
import { DomainError } from '../../shared/domain/domain-error.js';
import { RateLimitedError } from '../../modules/access/domain/invite-errors.js';
import { createProblemDetails } from './problem-details.js';
import { registerAccessRoutes } from './access-routes.js';
import { registerSessionRoutes } from './session-routes.js';
import { createFamilyBodyDocumentation, registerFamilyRoutes } from './family-routes.js';
import { onboardingUploadBodyDocumentation, registerMediaRoutes } from './media-routes.js';
import { registerProfileRoutes } from './profile-routes.js';
import { registerTaskRoutes } from './task-routes.js';
import { registerRoutineRoutes } from './routine-routes.js';
import { MissionReopenRequiresConfirmationError } from '../../modules/tasks/domain/task-reopening-errors.js';
import { registerMissionRoutes } from './mission-routes.js';
import { registerMemberRoutes } from './member-routes.js';
import { registerRewardRoutes } from './reward-routes.js';
import { registerReportRoutes } from './report-routes.js';
import { registerKidsSignalRoutes } from './kids-signal-routes.js';
import { registerFamilyApplauseRoutes } from './family-applause-routes.js';

export function buildHttpApp(
  container: ApplicationContainer,
  config: Configuration,
): FastifyInstance {
  const app = Fastify({
    // Só atrás de proxy confiável: caso contrário `X-Forwarded-For` é forjável e
    // o limite por origem do ingresso por convite (SPEC-005) seria contornável.
    trustProxy: config.TRUST_PROXY,
    genReqId: (req) => {
      const headerId = req.headers['x-request-id'];
      if (typeof headerId === 'string' && headerId.length > 0) {
        return headerId;
      }
      return randomUUID();
    },
    logger: false, // Observability is handled via container.logger and custom hooks
    ajv: {
      // O default do Fastify (`removeAdditional: true`) apaga em silêncio os
      // campos fora do schema com `additionalProperties: false`. O contrato exige
      // o contrário: campo desconhecido é recusado com UNKNOWN_FIELD (CA-04).
      customOptions: { removeAdditional: false },
    },
  });

  // Plugins
  app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  });

  app.register(sensible);

  // A especificação é gerada dos schemas de rota, mantendo a documentação de
  // teste alinhada ao contrato realmente validado e serializado pelo Fastify.
  // Estes plugins precisam ser registrados antes das rotas para descobri-las.
  app.register(swagger, {
    transform: ({ schema, url }) => ({
      schema:
        url === '/v1/onboarding/media'
          ? { ...schema, body: onboardingUploadBodyDocumentation }
          : url === '/v1/families'
            ? { ...schema, body: createFamilyBodyDocumentation }
            : schema,
      url,
    }),
    openapi: {
      openapi: '3.1.0',
      info: {
        title: 'App Rotina Familiar API',
        version: '0.1.0',
        description: 'API HTTP do MVP. Os recursos protegidos usam Bearer tokens opacos.',
      },
      servers: [{ url: config.API_BASE_URL, description: 'API configurada para o ambiente atual' }],
      tags: [
        { name: 'Operational', description: 'Sondas e metadados operacionais.' },
        { name: 'Access', description: 'Autenticação, convite e início de sessão.' },
        { name: 'Family', description: 'Onboarding e criação de família.' },
        { name: 'Members', description: 'Consulta e criação de perfis da família.' },
        { name: 'Media', description: 'Upload de mídia privada.' },
        { name: 'Profile', description: 'Dados do próprio perfil.' },
        { name: 'Tasks', description: 'Gestão de tarefas únicas.' },
        { name: 'Kids', description: 'Sinalização de tarefas Kids e avaliação administrativa.' },
        { name: 'Reports', description: 'Snapshots para relatórios locais.' },
        {
          name: 'Routines',
          description: 'Configuração de recorrência e materialização de ocorrências.',
        },
        { name: 'Missions', description: 'Missões coletivas, participações e badges.' },
        { name: 'Rewards', description: 'Catálogo de recompensas coletivas.' },
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'Opaque access token',
            description: 'Access token emitido após autenticação ou criação da família.',
          },
        },
      },
    },
  });

  app.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: { docExpansion: 'list', deepLinking: true, persistAuthorization: true },
  });

  // Request logging & tracking hook
  app.addHook('onRequest', async (req: FastifyRequest) => {
    container.logger.debug(`Incoming request: ${req.method} ${req.url}`, {
      requestId: req.id,
      method: req.method,
      url: req.url,
      ip: req.ip,
    });
  });

  app.addHook('onResponse', async (req: FastifyRequest, reply: FastifyReply) => {
    container.logger.info(`Completed request: ${req.method} ${req.url} -> ${reply.statusCode}`, {
      requestId: req.id,
      method: req.method,
      url: req.url,
      statusCode: reply.statusCode,
      responseTimeMs: reply.elapsedTime,
    });
  });

  // Helper type guard
  const isRecord = (val: unknown): val is Record<string, unknown> =>
    typeof val === 'object' && val !== null;

  // RFC 9457 Problem Details Error Handler (backend-contracts.md §1)
  app.setErrorHandler((error: unknown, req, reply) => {
    const requestId = req.id;

    if (error instanceof DomainError) {
      const problem = createProblemDetails({
        status: error.statusCode,
        code: error.code,
        title:
          error instanceof MissionReopenRequiresConfirmationError
            ? 'Confirmação necessária'
            : error.name,
        type:
          error instanceof MissionReopenRequiresConfirmationError
            ? 'https://api.rotinafamiliar.app/problems/mission-reopen-requires-confirmation'
            : undefined,
        detail: error.message,
        requestId,
        fieldErrors: error.fieldErrors,
      });

      if (error instanceof RateLimitedError) {
        reply.header('Retry-After', String(error.retryAfterSeconds));
      }

      return reply
        .status(error.statusCode)
        .header('Content-Type', 'application/problem+json')
        .send(
          error instanceof MissionReopenRequiresConfirmationError
            ? {
                ...problem,
                missionsAffected: error.missionsAffected,
                hasAcceptedReward: error.hasAcceptedReward,
              }
            : problem,
        );
    }

    // Fastify schema validation error
    if (isRecord(error) && Array.isArray(error.validation)) {
      const issues = error.validation as Array<{
        instancePath?: string;
        message?: string;
        keyword?: string;
        params?: { additionalProperty?: string };
      }>;
      const fieldErrors: Record<string, string[]> = {};

      // Campo fora do schema tem código próprio no contrato (UNKNOWN_FIELD) e o
      // nome do campo recusado vai em `fieldErrors`.
      const unknownFields = issues.filter(
        (issue) => issue.keyword === 'additionalProperties' && issue.params?.additionalProperty,
      );

      for (const vErr of unknownFields.length > 0 ? unknownFields : issues) {
        const field =
          vErr.params?.additionalProperty ?? (vErr.instancePath?.replace(/^\//, '') || 'body');
        if (!fieldErrors[field]) {
          fieldErrors[field] = [];
        }
        fieldErrors[field].push(
          unknownFields.length > 0 ? 'UNKNOWN_FIELD' : vErr.message || 'Invalid value',
        );
      }

      const problem = createProblemDetails({
        status: 400,
        // Códigos estáveis do contrato (SPEC-001 §5.2, SPEC-002 §5.3).
        code: unknownFields.length > 0 ? 'UNKNOWN_FIELD' : 'VALIDATION_FAILED',
        title: 'Bad Request',
        detail: typeof error.message === 'string' ? error.message : 'Validation failed',
        requestId,
        fieldErrors,
      });

      return reply.status(400).header('Content-Type', 'application/problem+json').send(problem);
    }

    // Unexpected internal server error
    container.logger.error('Unhandled internal server error', error, { requestId });

    const statusCode =
      isRecord(error) && typeof error.statusCode === 'number' && error.statusCode < 500
        ? error.statusCode
        : 500;
    const errorMessage = error instanceof Error ? error.message : String(error);

    const problem = createProblemDetails({
      status: statusCode,
      code: 'INTERNAL_SERVER_ERROR',
      title: 'Internal Server Error',
      detail:
        config.NODE_ENV === 'production' ? 'An unexpected internal error occurred.' : errorMessage,
      requestId,
    });

    return reply
      .status(problem.status)
      .header('Content-Type', 'application/problem+json')
      .send(problem);
  });

  // --------------------------------------------------------------------------
  // Operational Routes (backend-contracts.md §6)
  // --------------------------------------------------------------------------

  app.register(async (scope) => {
    // GET /health/live - Liveness probe (process is up)
    scope.get(
      '/health/live',
      { schema: { tags: ['Operational'], summary: 'Liveness probe' } },
      async (_req, reply) => {
        return reply.status(200).send({
          status: 'ok',
          environment: config.NODE_ENV,
          timestamp: container.clock.nowIsoString(),
        });
      },
    );

    // GET /health/ready - Readiness probe (essential dependencies verified)
    scope.get(
      '/health/ready',
      { schema: { tags: ['Operational'], summary: 'Readiness probe' } },
      async (_req, reply) => {
        const dbHealth = await container.dbPool.checkHealth();

        if (!dbHealth.isHealthy) {
          return reply.status(503).send({
            status: 'not_ready',
            checks: {
              database: {
                status: 'unhealthy',
                error: dbHealth.error,
              },
            },
            timestamp: container.clock.nowIsoString(),
          });
        }

        return reply.status(200).send({
          status: 'ready',
          checks: {
            database: {
              status: 'healthy',
              latencyMs: dbHealth.latencyMs,
            },
          },
          timestamp: container.clock.nowIsoString(),
        });
      },
    );

    // GET /v1 - API root / info
    scope.get(
      '/v1',
      { schema: { tags: ['Operational'], summary: 'API metadata' } },
      async (_req, reply) => {
        return reply.status(200).send({
          name: 'App Rotina Familiar API',
          version: '0.1.0',
          status: 'operational',
          environment: config.NODE_ENV,
          timestamp: container.clock.nowIsoString(),
        });
      },
    );
  });

  // --------------------------------------------------------------------------
  // Rotas de módulo sob o prefixo /v1 (BA-20)
  // --------------------------------------------------------------------------
  app.register(
    async (scope) => {
      // `no-store` em todas as rotas de Access e de sessão (backend-contracts.md
      // §1): `POST /access/apple` e `POST /access/refresh` emitem credenciais no
      // corpo, e uma resposta de `/me/session` guardada em cache prolongaria uma
      // sessão já revogada (SPEC-001 §5.3). O hook cobre também as respostas de
      // erro, que um header posto em cada handler deixaria de fora. Um handler
      // que já definiu uma política mais específica (ex.: `private, no-store` do
      // conteúdo de mídia, SPEC-006 CA-15) a mantém.
      scope.addHook('onSend', async (_request, reply) => {
        if (!reply.hasHeader('Cache-Control')) {
          reply.header('Cache-Control', 'no-store');
        }
      });

      registerAccessRoutes(scope, container);
      registerSessionRoutes(scope, container);
      registerFamilyRoutes(scope, container);
      registerMemberRoutes(scope, container);
      registerMediaRoutes(scope, container);
      registerProfileRoutes(scope, container);
      registerTaskRoutes(scope, container);
      registerRoutineRoutes(scope, container);
      registerMissionRoutes(scope, container);
      registerRewardRoutes(scope, container);
      registerReportRoutes(scope, container);
      registerKidsSignalRoutes(scope, container);
      registerFamilyApplauseRoutes(scope, container);
    },
    { prefix: '/v1' },
  );

  return app;
}
