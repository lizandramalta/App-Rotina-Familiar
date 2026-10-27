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

interface FamilyQuery {
  readonly startDate?: string;
  readonly endDate?: string;
  readonly memberId?: string;
  readonly status?: string;
  readonly cursor?: string;
}

interface MemberTaskParams {
  readonly memberId: string;
}

interface TaskBody {
  readonly title?: unknown;
  readonly weight?: unknown;
  readonly scheduledDate?: unknown;
  readonly assigneeIds?: unknown;
  readonly note?: unknown;
  readonly signalResolution?: unknown;
}

interface ReopeningBody {
  readonly confirm?: boolean;
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
  required: ['items', 'nextCursor', 'familyCreatedAt'],
  properties: {
    items: {
      type: 'array',
      items: {
        ...taskResponseSchema,
        required: [...taskResponseSchema.required, 'displayStatus'],
        properties: {
          ...taskResponseSchema.properties,
          status: { enum: ['pending', 'awaitingConfirmation', 'completed'] },
          displayStatus: { enum: ['pending', 'awaitingConfirmation', 'completed'] },
        },
      },
    },
    nextCursor: { type: ['string', 'null'] },
    // Limite inferior do carrossel pessoal (RN49), YYYY-MM-DD local à família — SPEC-009 E-05.
    familyCreatedAt: { type: 'string' },
  },
} as const;

const ownProgressResponseSchema = {
  type: 'object',
  required: ['total', 'completed', 'percentage', 'familyCreatedAt'],
  properties: {
    total: { type: 'integer', minimum: 0 },
    completed: { type: 'integer', minimum: 0 },
    percentage: { type: ['number', 'null'], minimum: 0, maximum: 100 },
    // Limite inferior do carrossel pessoal (RN49), YYYY-MM-DD local à família — SPEC-009 E-05.
    familyCreatedAt: { type: 'string' },
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

const taskReopeningResultSchema = {
  type: 'object',
  required: ['task', 'affectedResources'],
  additionalProperties: false,
  properties: {
    task: taskResponseSchema,
    affectedResources: {
      type: 'object',
      required: ['missionsReopened', 'participationsRemoved', 'badgesRemoved', 'rewardRemoved'],
      additionalProperties: false,
      properties: {
        missionsReopened: {
          type: 'array',
          items: {
            type: 'object',
            required: ['id', 'title', 'status'],
            properties: {
              id: { type: 'string' },
              title: { type: 'string' },
              status: { const: 'inProgress' },
            },
          },
        },
        participationsRemoved: { type: 'integer', minimum: 0 },
        badgesRemoved: {
          type: 'array',
          items: {
            type: 'object',
            required: ['memberId', 'tier'],
            properties: {
              memberId: { type: 'string' },
              tier: { enum: ['bronze', 'silver', 'gold', 'diamond'] },
            },
          },
        },
        rewardRemoved: { type: 'boolean' },
      },
    },
  },
} as const;

const reopeningConflictSchema = {
  ...problemResponseSchema,
  properties: {
    ...problemResponseSchema.properties,
    missionsAffected: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'title'],
        properties: { id: { type: 'string' }, title: { type: 'string' } },
      },
    },
    hasAcceptedReward: { type: 'boolean' },
  },
} as const;

const referenceDateQuerySchema = {
  type: 'object',
  required: ['referenceDate'],
  additionalProperties: false,
  properties: { referenceDate: { type: 'string' } },
} as const;

const familyRangeQuerySchema = {
  type: 'object',
  required: ['startDate', 'endDate'],
  additionalProperties: false,
  properties: { startDate: { type: 'string' }, endDate: { type: 'string' } },
} as const;

const familyProgressResponseSchema = {
  type: 'object',
  required: ['total', 'completed', 'pending', 'awaitingConfirmation', 'percentage'],
  properties: {
    total: { type: 'integer', minimum: 0 },
    completed: { type: 'integer', minimum: 0 },
    pending: { type: 'integer', minimum: 0 },
    awaitingConfirmation: { type: 'integer', minimum: 0 },
    percentage: { type: ['number', 'null'], minimum: 0, maximum: 100 },
  },
} as const;

const familyOverviewResponseSchema = {
  type: 'object',
  required: ['startDate', 'endDate', 'familyCreatedAt', 'progress', 'members'],
  properties: {
    startDate: { type: 'string' },
    endDate: { type: 'string' },
    familyCreatedAt: { type: 'string' },
    progress: familyProgressResponseSchema,
    members: {
      type: 'array',
      items: {
        ...familyProgressResponseSchema,
        required: [...familyProgressResponseSchema.required, 'memberId', 'name', 'role'],
        properties: {
          ...familyProgressResponseSchema.properties,
          memberId: { type: 'string' },
          name: { type: 'string' },
          role: { enum: ['administrator', 'member', 'kids'] },
        },
      },
    },
  },
} as const;

const familyTasksResponseSchema = {
  type: 'object',
  required: ['startDate', 'endDate', 'items', 'nextCursor'],
  properties: {
    startDate: { type: 'string' },
    endDate: { type: 'string' },
    items: ownTasksResponseSchema.properties.items,
    nextCursor: { type: ['string', 'null'] },
  },
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

    // SPEC-009 CA-05/07/08/10/12: family scope and role projection are server-side.
    scope.get<{ Querystring: FamilyQuery }>(
      '/family/overview',
      {
        schema: {
          tags: ['Family'],
          summary: 'Get family task progress and member progress for an inclusive date range',
          security: [{ bearerAuth: [] }],
          querystring: {
            ...familyRangeQuerySchema,
            required: [],
          },
          response: {
            200: familyOverviewResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
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
            await container.getFamilyOverviewUseCase.execute(
              requireActor(request),
              request.query.startDate,
              request.query.endDate,
            ),
          ),
    );

    scope.get<{ Querystring: FamilyQuery }>(
      '/family/tasks',
      {
        schema: {
          tags: ['Family'],
          summary: 'List family tasks for an inclusive date range and optional member or status',
          security: [{ bearerAuth: [] }],
          querystring: {
            ...familyRangeQuerySchema,
            properties: {
              ...familyRangeQuerySchema.properties,
              memberId: { type: 'string' },
              status: { type: 'string' },
              cursor: { type: 'string' },
            },
          },
          response: {
            200: familyTasksResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
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
            await container.getFamilyTasksUseCase.execute(requireActor(request), request.query),
          ),
    );

    scope.get<{ Params: MemberTaskParams; Querystring: FamilyQuery }>(
      '/family/members/:memberId/tasks',
      {
        schema: {
          tags: ['Family'],
          summary: 'List a family member tasks for an inclusive date range',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          querystring: {
            ...familyRangeQuerySchema,
            properties: { ...familyRangeQuerySchema.properties, cursor: { type: 'string' } },
          },
          response: {
            200: familyTasksResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
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
            await container.getFamilyTasksUseCase.execute(requireActor(request), {
              ...request.query,
              memberId: request.params.memberId,
            }),
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

    scope.post<{ Params: TaskParams; Body: ReopeningBody }>(
      '/tasks/:taskId/reopening',
      {
        schema: {
          tags: ['Tasks'],
          summary: 'Reopen a completed task and reverse its mission effects',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['taskId'],
            additionalProperties: false,
            properties: { taskId: { type: 'string' } },
          },
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { confirm: { type: 'boolean' } },
          },
          response: {
            200: taskReopeningResultSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            409: reopeningConflictSchema,
            503: problemResponseSchema,
          },
        },
        preValidation(request, _reply, done) {
          if (request.body === undefined) {
            request.body = {};
          }
          done();
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.reopenTaskUseCase.execute(
              requireActor(request),
              request.params.taskId,
              request.body.confirm === true,
              request.id,
            ),
          ),
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
