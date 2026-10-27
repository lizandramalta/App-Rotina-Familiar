import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { DomainError } from '../../shared/domain/domain-error.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface RoutineParams {
  readonly routineId: string;
}

interface CreateRoutineBody {
  readonly title?: unknown;
  readonly weight?: unknown;
  readonly assigneeIds?: unknown;
  readonly note?: unknown;
  readonly startDate?: unknown;
  readonly frequencyDays?: unknown;
}

interface UpdateFutureRoutineBody {
  readonly fromTaskId?: unknown;
  readonly title?: unknown;
  readonly weight?: unknown;
  readonly assigneeIds?: unknown;
  readonly note?: unknown;
}

interface DeleteFutureRoutineTasksBody {
  readonly fromTaskId?: unknown;
}

const routineResponseSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'id',
    'title',
    'weight',
    'assigneeIds',
    'note',
    'startDate',
    'frequencyDays',
    'isActive',
    'materializationState',
  ],
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    weight: { type: 'integer' },
    assigneeIds: { type: 'array', items: { type: 'string' } },
    note: { type: ['string', 'null'] },
    startDate: { type: 'string' },
    frequencyDays: { type: 'integer' },
    isActive: { type: 'boolean' },
    materializationState: { type: 'string', enum: ['pending', 'complete'] },
  },
} as const;

const problemResponseSchema = {
  type: 'object',
  additionalProperties: false,
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

const routineParamsSchema = {
  type: 'object',
  required: ['routineId'],
  additionalProperties: false,
  properties: { routineId: { type: 'string' } },
} as const;

const updateFutureRoutineResponseSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['routine', 'updatedTaskIds', 'preservedTaskIds'],
  properties: {
    routine: routineResponseSchema,
    updatedTaskIds: { type: 'array', items: { type: 'string' } },
    preservedTaskIds: { type: 'array', items: { type: 'string' } },
  },
} as const;

const deleteFutureRoutineTasksResponseSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['routineId', 'deletedTaskIds', 'preservedTaskIds', 'generationEnded'],
  properties: {
    routineId: { type: 'string' },
    deletedTaskIds: { type: 'array', items: { type: 'string' } },
    preservedTaskIds: { type: 'array', items: { type: 'string' } },
    generationEnded: { type: 'boolean' },
  },
} as const;

function logRoutineManagementDenied(
  container: ApplicationContainer,
  requestId: string,
  actorId: string,
  error: unknown,
): void {
  if (error instanceof DomainError && [403, 404, 409].includes(error.statusCode)) {
    container.logger.info('routine_management_denied', {
      requestId,
      actorId,
      code: error.code,
    });
  }
}

/** Rotas de rotina — SPEC-008 Fases 1 e 2. */
export function registerRoutineRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.post<{ Body: CreateRoutineBody }>(
      '/routines',
      {
        schema: {
          tags: ['Routines'],
          summary: 'Create a routine and start materializing its occurrences',
          security: [{ bearerAuth: [] }],
          body: {
            type: 'object',
            additionalProperties: false,
            properties: {
              title: {},
              weight: {},
              assigneeIds: {},
              note: {},
              startDate: {},
              frequencyDays: {},
            },
          },
          response: {
            201: routineResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const routine = await container.createRoutineUseCase.execute({
          actor: requireActor(request),
          title: request.body.title,
          weight: request.body.weight,
          assigneeIds: request.body.assigneeIds,
          note: request.body.note,
          startDate: request.body.startDate,
          frequencyDays: request.body.frequencyDays,
        });
        return reply
          .status(201)
          .header('Location', `/v1/routines/${routine.id}`)
          .header('Cache-Control', 'no-store')
          .send(routine);
      },
    );

    scope.get<{ Params: RoutineParams }>(
      '/routines/:routineId',
      {
        schema: {
          tags: ['Routines'],
          summary: 'Get a routine configuration and its materialization progress',
          security: [{ bearerAuth: [] }],
          params: routineParamsSchema,
          response: {
            200: routineResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.getRoutineUseCase.execute(
              requireActor(request),
              request.params.routineId,
            ),
          ),
    );

    scope.patch<{ Params: RoutineParams; Body: UpdateFutureRoutineBody }>(
      '/routines/:routineId',
      {
        schema: {
          tags: ['Routines'],
          summary: 'Update a routine from one occurrence onward',
          security: [{ bearerAuth: [] }],
          params: routineParamsSchema,
          body: {
            type: 'object',
            additionalProperties: false,
            properties: {
              fromTaskId: {},
              title: {},
              weight: {},
              assigneeIds: {},
              note: {},
            },
          },
          response: {
            200: updateFutureRoutineResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            409: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const actor = requireActor(request);
        try {
          const result = await container.updateFutureRoutineUseCase.execute({
            actor,
            routineId: request.params.routineId,
            fromTaskId: request.body?.fromTaskId,
            title: request.body?.title,
            weight: request.body?.weight,
            assigneeIds: request.body?.assigneeIds,
            note: request.body?.note,
          });
          return reply.status(200).header('Cache-Control', 'no-store').send(result);
        } catch (error) {
          logRoutineManagementDenied(container, request.id, actor.memberId, error);
          throw error;
        }
      },
    );

    scope.post<{ Params: RoutineParams; Body: DeleteFutureRoutineTasksBody }>(
      '/routines/:routineId/future-task-deletions',
      {
        schema: {
          tags: ['Routines'],
          summary: 'Delete eligible future occurrences and end routine generation',
          security: [{ bearerAuth: [] }],
          params: routineParamsSchema,
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { fromTaskId: {} },
          },
          response: {
            200: deleteFutureRoutineTasksResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            409: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const actor = requireActor(request);
        try {
          const result = await container.deleteFutureRoutineTasksUseCase.execute({
            actor,
            routineId: request.params.routineId,
            fromTaskId: request.body?.fromTaskId,
          });
          return reply.status(200).header('Cache-Control', 'no-store').send(result);
        } catch (error) {
          logRoutineManagementDenied(container, request.id, actor.memberId, error);
          throw error;
        }
      },
    );
  });
}
