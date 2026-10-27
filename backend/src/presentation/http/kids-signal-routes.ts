import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface TaskParams {
  readonly taskId: string;
}
interface SignalParams {
  readonly signalId: string;
}
interface SignalBody {
  readonly photoMediaId?: unknown;
}
interface DecisionBody {
  readonly decision?: unknown;
}
interface QueueQuery {
  readonly cursor?: string;
}

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
const taskSchema = {
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
    status: { enum: ['pending', 'awaitingConfirmation', 'completed'] },
    routineId: { type: ['string', 'null'] },
    createdAt: { type: 'string' },
  },
} as const;
const signalSummarySchema = {
  type: 'object',
  required: ['signalId', 'task', 'signaledBy', 'signaledAt', 'hasPhoto'],
  properties: {
    signalId: { type: 'string' },
    task: {
      type: 'object',
      required: ['id', 'title'],
      properties: { id: { type: 'string' }, title: { type: 'string' } },
    },
    signaledBy: {
      type: 'object',
      required: ['id', 'name'],
      properties: { id: { type: 'string' }, name: { type: 'string' } },
    },
    signaledAt: { type: 'string' },
    hasPhoto: { type: 'boolean' },
  },
} as const;
const mutationSchema = {
  type: 'object',
  required: ['task', 'decisionOutcome', 'applied'],
  properties: {
    task: taskSchema,
    decisionOutcome: { enum: ['confirmed', 'rejected', 'closedByManualCompletion'] },
    applied: { type: 'boolean' },
  },
} as const;

/** SPEC-012/013: Kids signaling and administrator review. */
export function registerKidsSignalRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));
    scope.post<{ Params: TaskParams; Body: SignalBody }>(
      '/tasks/:taskId/signals',
      {
        preValidation: async (request) => {
          request.body ??= {};
        },
        schema: {
          tags: ['Kids'],
          summary: 'Signal a pending assigned task',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['taskId'],
            properties: { taskId: { type: 'string', format: 'uuid' } },
          },
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { photoMediaId: { type: ['string', 'null'] } },
          },
          response: {
            201: {
              type: 'object',
              required: ['task', 'signal'],
              properties: {
                task: taskSchema,
                signal: {
                  type: 'object',
                  required: ['id', 'signaledAt', 'hasPhoto'],
                  properties: {
                    id: { type: 'string' },
                    signaledAt: { type: 'string' },
                    hasPhoto: { type: 'boolean' },
                  },
                },
              },
            },
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
      async (request, reply) =>
        reply
          .status(201)
          .header('Cache-Control', 'no-store')
          .send(
            await container.signalTaskUseCase.execute(
              requireActor(request),
              request.params.taskId,
              request.body.photoMediaId,
            ),
          ),
    );

    scope.get<{ Querystring: QueueQuery }>(
      '/kids/signals',
      {
        schema: {
          tags: ['Kids'],
          summary: 'List current Kids signals, oldest first',
          security: [{ bearerAuth: [] }],
          querystring: {
            type: 'object',
            additionalProperties: false,
            properties: { cursor: { type: 'string' } },
          },
          response: {
            200: {
              type: 'object',
              required: ['items', 'nextCursor'],
              properties: {
                items: { type: 'array', items: signalSummarySchema },
                nextCursor: { type: ['string', 'null'] },
              },
            },
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
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
            await container.listKidsSignalsUseCase.execute(
              requireActor(request),
              request.query.cursor,
            ),
          ),
    );

    scope.get<{ Params: SignalParams }>(
      '/kids/signals/:signalId',
      {
        schema: {
          tags: ['Kids'],
          summary: 'Get a current Kids signal for review',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['signalId'],
            properties: { signalId: { type: 'string', format: 'uuid' } },
          },
          response: {
            200: {
              type: 'object',
              required: [
                ...signalSummarySchema.required,
                'assignees',
                'photoMediaId',
                'capabilities',
              ],
              properties: {
                ...signalSummarySchema.properties,
                task: taskSchema,
                assignees: {
                  type: 'array',
                  items: {
                    type: 'object',
                    required: ['id', 'name'],
                    properties: { id: { type: 'string' }, name: { type: 'string' } },
                  },
                },
                photoMediaId: { type: ['string', 'null'] },
                capabilities: {
                  type: 'object',
                  required: ['canConfirm', 'canReject'],
                  properties: { canConfirm: { type: 'boolean' }, canReject: { type: 'boolean' } },
                },
              },
            },
            400: problemResponseSchema,
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
            await container.getKidsSignalUseCase.execute(
              requireActor(request),
              request.params.signalId,
            ),
          ),
    );

    scope.post<{ Params: SignalParams; Body: DecisionBody }>(
      '/kids/signals/:signalId/decision',
      {
        schema: {
          tags: ['Kids'],
          summary: 'Confirm or reject a Kids signal',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['signalId'],
            properties: { signalId: { type: 'string', format: 'uuid' } },
          },
          body: {
            type: 'object',
            additionalProperties: false,
            required: ['decision'],
            properties: { decision: { type: 'string', enum: ['confirm', 'reject'] } },
          },
          response: {
            200: mutationSchema,
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
            await container.decideKidsSignalUseCase.execute(
              requireActor(request),
              request.params.signalId,
              request.body.decision,
            ),
          ),
    );
  });
}
