import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface WeeklyQuery {
  readonly referenceDate?: string;
}

const snapshotResponseSchema = {
  type: 'object',
  required: [
    'period',
    'timeZoneId',
    'isTransition',
    'generatedAt',
    'isPartial',
    'progress',
    'load',
    'members',
  ],
  properties: {
    period: {
      type: 'object',
      required: ['startDate', 'endDate'],
      properties: { startDate: { type: 'string' }, endDate: { type: 'string' } },
    },
    timeZoneId: { type: 'string' },
    isTransition: { type: 'boolean' },
    generatedAt: { type: 'string' },
    isPartial: { type: 'boolean' },
    progress: {
      type: 'object',
      required: ['total', 'completed', 'percentage'],
      properties: {
        total: { type: 'integer' },
        completed: { type: 'integer' },
        percentage: { type: ['number', 'null'] },
      },
    },
    load: {
      type: 'object',
      required: ['totalWeight'],
      properties: { totalWeight: { type: 'integer' } },
    },
    members: {
      type: 'array',
      items: {
        type: 'object',
        required: ['memberId', 'displayName', 'weight', 'completedTasks', 'percentage'],
        properties: {
          memberId: { type: ['string', 'null'] },
          displayName: { type: 'string' },
          weight: { type: 'integer' },
          completedTasks: { type: 'integer' },
          percentage: { type: ['number', 'null'] },
        },
      },
    },
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
  },
} as const;

/** SPEC-019 CA-01–04: JSON snapshot for local PDF rendering. */
export function registerReportRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));
    scope.get<{ Querystring: WeeklyQuery }>(
      '/reports/weekly-snapshot',
      {
        schema: {
          tags: ['Reports'],
          summary: 'Get a family weekly report snapshot',
          security: [{ bearerAuth: [] }],
          querystring: {
            type: 'object',
            additionalProperties: false,
            required: ['referenceDate'],
            properties: { referenceDate: { type: 'string' } },
          },
          response: {
            200: snapshotResponseSchema,
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
            await container.getWeeklyReportSnapshotUseCase.execute(
              requireActor(request),
              request.query.referenceDate,
            ),
          ),
    );
  });
}
