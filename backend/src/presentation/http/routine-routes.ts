import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
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

const routineResponseSchema = {
  type: 'object',
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

/** Rotas de rotina — SPEC-008 Fase 1: `CreateRoutine`/`GetRoutine` apenas. */
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
          params: {
            type: 'object',
            required: ['routineId'],
            additionalProperties: false,
            properties: { routineId: { type: 'string' } },
          },
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
  });
}
