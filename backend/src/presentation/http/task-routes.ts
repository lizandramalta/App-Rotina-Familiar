import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';
import { DomainError } from '../../shared/domain/domain-error.js';

interface TaskParams {
  readonly taskId: string;
}

interface OwnTasksQuery {
  readonly referenceDate: string;
  readonly cursor?: string;
}

interface OwnProgressQuery {
  readonly referenceDate: string;
}

interface TaskBody {
  readonly title?: unknown;
  readonly weight?: unknown;
  readonly scheduledDate?: unknown;
  readonly assigneeIds?: unknown;
  readonly note?: unknown;
  readonly signalResolution?: unknown;
}

const taskProperties = {
  title: {},
  weight: {},
  scheduledDate: {},
  assigneeIds: {},
  note: {},
  signalResolution: {},
} as const;

const taskResponseSchema = {
  type: 'object',
  required: [
    'id',
    'title',
    'weight',
    'scheduledDate',
    'assigneeIds',
    'note',
    'status',
    'routineId',
    'createdAt',
  ],
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    weight: { type: 'integer' },
    scheduledDate: { type: 'string' },
    assigneeIds: { type: 'array', items: { type: 'string' } },
    note: { type: ['string', 'null'] },
    status: { type: 'string' },
    routineId: { type: ['string', 'null'] },
    createdAt: { type: 'string' },
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

const ownTasksResponseSchema = {
  type: 'object',
  required: ['items', 'nextCursor'],
  properties: {
    items: { type: 'array', items: taskResponseSchema },
    nextCursor: { type: ['string', 'null'] },
  },
} as const;

const ownProgressResponseSchema = {
  type: 'object',
  required: ['total', 'completed', 'percentage'],
  properties: {
    total: { type: 'integer', minimum: 0 },
    completed: { type: 'integer', minimum: 0 },
    percentage: { type: ['number', 'null'], minimum: 0, maximum: 100 },
  },
} as const;

const affectedResourceSchema = {
  anyOf: [
    {
      type: 'object',
      required: ['type', 'id'],
      additionalProperties: false,
      properties: { type: { const: 'task' }, id: { type: 'string' } },
    },
    {
      type: 'object',
      required: ['type', 'referenceDate'],
      additionalProperties: false,
      properties: {
        type: { enum: ['ownTasks', 'ownProgress'] },
        referenceDate: { type: 'string' },
      },
    },
  ],
} as const;

const taskMutationResultSchema = {
  type: 'object',
  required: ['task', 'affectedResources'],
  additionalProperties: false,
  properties: {
    task: taskResponseSchema,
    affectedResources: { type: 'array', items: affectedResourceSchema },
  },
} as const;

const referenceDateQuerySchema = {
  type: 'object',
  required: ['referenceDate'],
  additionalProperties: false,
  properties: { referenceDate: { type: 'string' } },
} as const;

function requireEmptyCompletionBody(body: unknown): void {
  if (body === undefined) {
    return;
  }
  if (typeof body === 'object' && body !== null && !Array.isArray(body)) {
    const fields = Object.keys(body);
    if (fields.length === 0) {
      return;
    }
    throw new DomainError({
      message: 'The completion command does not accept a request body.',
      code: 'UNKNOWN_FIELD',
      statusCode: 400,
      fieldErrors: Object.fromEntries(fields.map((field) => [field, ['UNKNOWN_FIELD']])),
    });
  }
  throw new DomainError({
    message: 'The completion command does not accept a request body.',
    code: 'VALIDATION_FAILED',
    statusCode: 400,
  });
}

/** Rotas de tarefas — SPEC-007 e consulta pessoal diária da SPEC-009 Fase 1. */
export function registerTaskRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.get<{ Querystring: OwnTasksQuery }>(
      '/me/tasks',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'List the authenticated member tasks for one day',
          security: [{ bearerAuth: [] }],
          querystring: {
            ...referenceDateQuerySchema,
            properties: { ...referenceDateQuerySchema.properties, cursor: { type: 'string' } },
          },
          response: {
            200: ownTasksResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getOwnTasksUseCase.execute(
              requireActor(request),
              request.query.referenceDate,
              request.query.cursor,
            ),
          ),
    );

    scope.get<{ Querystring: OwnProgressQuery }>(
      '/me/progress',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Get the authenticated member daily task progress',
          security: [{ bearerAuth: [] }],
          querystring: referenceDateQuerySchema,
          response: {
            200: ownProgressResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getOwnProgressUseCase.execute(
              requireActor(request),
              request.query.referenceDate,
            ),
          ),
    );

    scope.post<{ Body: TaskBody }>(
      '/tasks',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Create a single task',
          security: [{ bearerAuth: [] }],
          body: { type: 'object', additionalProperties: false, properties: taskProperties },
          response: { 201: taskResponseSchema },
        },
      },
      async (request, reply) => {
        const task = await container.createTaskUseCase.execute({
          actor: requireActor(request),
          title: request.body.title,
          weight: request.body.weight,
          scheduledDate: request.body.scheduledDate,
          assigneeIds: request.body.assigneeIds,
          note: request.body.note,
        });
        return reply
          .status(201)
          .header('Location', `/v1/tasks/${task.id}`)
          .header('Cache-Control', 'no-store')
          .send(task);
      },
    );

    scope.get<{ Params: TaskParams }>(
      '/tasks/:taskId',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Get a single task',
          security: [{ bearerAuth: [] }],
          response: { 200: taskResponseSchema },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getTaskUseCase.execute(requireActor(request), request.params.taskId),
          ),
    );

    scope.post<{ Params: TaskParams; Body: unknown }>(
      '/tasks/:taskId/completion',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Complete an eligible task with final assignee credits',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['taskId'],
            additionalProperties: false,
            properties: { taskId: { type: 'string' } },
          },
          response: {
            200: taskMutationResultSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            409: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        requireEmptyCompletionBody(request.body);
        return reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.completeTaskUseCase.execute(
              requireActor(request),
              request.params.taskId,
            ),
          );
      },
    );

    scope.patch<{ Params: TaskParams; Body: TaskBody }>(
      '/tasks/:taskId',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Edit a single task',
          security: [{ bearerAuth: [] }],
          body: { type: 'object', additionalProperties: false, properties: taskProperties },
          response: { 200: taskResponseSchema },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.editTaskUseCase.execute({
              actor: requireActor(request),
              taskId: request.params.taskId,
              title: request.body.title,
              weight: request.body.weight,
              scheduledDate: request.body.scheduledDate,
              assigneeIds: request.body.assigneeIds,
              note: request.body.note,
              signalResolution: request.body.signalResolution,
            }),
          ),
    );

    scope.delete<{ Params: TaskParams }>(
      '/tasks/:taskId',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Delete a single task',
          security: [{ bearerAuth: [] }],
          response: {
            200: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.deleteTaskUseCase.execute(requireActor(request), request.params.taskId),
          ),
    );
  });
}
