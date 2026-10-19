import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface MissionParams {
  readonly missionId: string;
}

interface MissionBody {
  readonly title?: unknown;
  readonly note?: unknown;
  readonly taskIds?: unknown;
}

interface PageQuery {
  readonly cursor?: string;
  readonly query?: string;
}

const missionBodyProperties = { title: {}, note: {}, taskIds: {} } as const;

const missionResponseSchema = {
  type: 'object',
  required: ['id', 'title', 'note', 'status', 'taskIds', 'completedAt', 'createdAt'],
  properties: {
    id: { type: 'string' },
    familyId: { type: 'string' },
    title: { type: 'string' },
    note: { type: ['string', 'null'] },
    status: { type: 'string', enum: ['inProgress', 'completed'] },
    taskIds: { type: 'array', items: { type: 'string' } },
    completedAt: { type: ['string', 'null'] },
    // Ausente na projeção Kids (CA-19): resgate é ação de Administrador.
    isRedemptionAvailable: { type: 'boolean' },
    createdAt: { type: 'string' },
  },
} as const;

const missionListSchema = {
  type: 'object',
  required: ['items', 'nextCursor'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'title', 'status', 'taskCount', 'completedTaskCount'],
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          status: { type: 'string', enum: ['inProgress', 'completed'] },
          taskCount: { type: 'integer', minimum: 0 },
          completedTaskCount: { type: 'integer', minimum: 0 },
        },
      },
    },
    nextCursor: { type: ['string', 'null'] },
  },
} as const;

const taskOptionsSchema = {
  type: 'object',
  required: ['items', 'nextCursor'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'title', 'weight', 'scheduledDate', 'status', 'assigneeIds'],
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          weight: { type: 'integer' },
          scheduledDate: { type: 'string' },
          status: { type: 'string', enum: ['pending', 'awaitingConfirmation', 'completed'] },
          assigneeIds: { type: 'array', items: { type: 'string' } },
        },
      },
    },
    nextCursor: { type: ['string', 'null'] },
  },
} as const;

const problemResponseSchema = {
  type: 'object',
  required: ['type', 'title', 'status', 'code', 'requestId'],
  properties: {
    type: { type: 'string' },
    title: { type: 'string' },
    status: { type: 'integer' },
    code: { type: 'string' },
    requestId: { type: 'string' },
    fieldErrors: {
      type: 'object',
      additionalProperties: { type: 'array', items: { type: 'string' } },
    },
  },
} as const;

const missionParamsSchema = {
  type: 'object',
  required: ['missionId'],
  additionalProperties: false,
  properties: { missionId: { type: 'string' } },
} as const;

const errorResponses = {
  400: problemResponseSchema,
  401: problemResponseSchema,
  403: problemResponseSchema,
  404: problemResponseSchema,
  409: problemResponseSchema,
  422: problemResponseSchema,
  503: problemResponseSchema,
} as const;

/** Rotas de missões — SPEC-014 Fase 1 (SCRUM-66). */
export function registerMissionRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.post<{ Body: MissionBody }>(
      '/missions',
      {
        schema: {
          tags: ['Missions'],
          summary: 'Create a collective mission',
          security: [{ bearerAuth: [] }],
          body: { type: 'object', additionalProperties: false, properties: missionBodyProperties },
          response: { 201: missionResponseSchema, ...errorResponses },
        },
      },
      async (request, reply) => {
        const mission = await container.createMissionUseCase.execute({
          actor: requireActor(request),
          title: request.body.title,
          note: request.body.note,
          taskIds: request.body.taskIds,
        });
        return reply
          .status(201)
          .header('Location', `/v1/missions/${mission.id}`)
          .header('Cache-Control', 'no-store')
          .send(mission);
      },
    );

    scope.get<{ Querystring: PageQuery }>(
      '/missions',
      {
        schema: {
          tags: ['Missions'],
          summary: 'List family missions with minimal progress',
          security: [{ bearerAuth: [] }],
          querystring: {
            type: 'object',
            additionalProperties: false,
            properties: { cursor: { type: 'string' } },
          },
          response: { 200: missionListSchema, ...errorResponses },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.listMissionsUseCase.execute(
              requireActor(request),
              request.query.cursor,
            ),
          ),
    );

    // Rota estática registrada antes de `/missions/:missionId`.
    scope.get<{ Querystring: PageQuery }>(
      '/missions/task-options',
      {
        schema: {
          tags: ['Missions'],
          summary: 'List tasks that can be linked to a mission',
          security: [{ bearerAuth: [] }],
          querystring: {
            type: 'object',
            additionalProperties: false,
            properties: { query: { type: 'string' }, cursor: { type: 'string' } },
          },
          response: { 200: taskOptionsSchema, ...errorResponses },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getMissionTaskOptionsUseCase.execute(
              requireActor(request),
              request.query.query,
              request.query.cursor,
            ),
          ),
    );

    scope.get<{ Params: MissionParams }>(
      '/missions/:missionId',
      {
        schema: {
          tags: ['Missions'],
          summary: 'Get a mission (Kids receive a simplified projection)',
          security: [{ bearerAuth: [] }],
          params: missionParamsSchema,
          response: { 200: missionResponseSchema, ...errorResponses },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getMissionDetailUseCase.execute(
              requireActor(request),
              request.params.missionId,
            ),
          ),
    );

    scope.patch<{ Params: MissionParams; Body: MissionBody }>(
      '/missions/:missionId',
      {
        schema: {
          tags: ['Missions'],
          summary: 'Edit an in-progress mission',
          security: [{ bearerAuth: [] }],
          params: missionParamsSchema,
          body: { type: 'object', additionalProperties: false, properties: missionBodyProperties },
          response: { 200: missionResponseSchema, ...errorResponses },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.editMissionUseCase.execute({
              actor: requireActor(request),
              missionId: request.params.missionId,
              title: request.body.title,
              note: request.body.note,
              taskIds: request.body.taskIds,
            }),
          ),
    );
  });
}
