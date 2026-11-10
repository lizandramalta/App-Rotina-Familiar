import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { DependencyUnavailableError, DomainError } from '../../shared/domain/domain-error.js';
import { SessionExpiredError } from '../../modules/access/domain/access-errors.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

const recognitionSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'id',
    'period',
    'timeZoneId',
    'isTransition',
    'points',
    'completedTasks',
    'isTie',
    'processedAt',
    'openedAt',
  ],
  properties: {
    id: { type: 'string', format: 'uuid' },
    period: {
      type: 'object',
      required: ['startsAt', 'endsAt', 'referenceWeek'],
      properties: {
        startsAt: { type: 'string', format: 'date-time' },
        endsAt: { type: 'string', format: 'date-time' },
        referenceWeek: { type: 'string', format: 'date' },
      },
    },
    timeZoneId: { type: 'string' },
    isTransition: { type: 'boolean' },
    points: { type: 'integer', minimum: 1 },
    completedTasks: { type: 'integer', minimum: 1 },
    isTie: { type: 'boolean' },
    processedAt: { type: 'string', format: 'date-time' },
    openedAt: { type: ['string', 'null'], format: 'date-time' },
  },
} as const;
const problemSchema = {
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
const common = {
  tags: ['Recognition'],
  security: [{ bearerAuth: [] }],
  response: {
    200: recognitionSchema,
    400: problemSchema,
    401: problemSchema,
    404: problemSchema,
    503: problemSchema,
  },
};
const params = {
  type: 'object',
  additionalProperties: false,
  required: ['recognitionId'],
  properties: { recognitionId: { type: 'string', format: 'uuid' } },
} as const;

/** SPEC-020 CA-05/06. Nenhum resultado de outro titular, mesmo para Admin. */
export function registerRecognitionRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
): void {
  app.register(async (scope) => {
    const authenticate = createAuthenticationHook(container);
    scope.addHook('onRequest', async (request, reply) => {
      reply.header('Cache-Control', 'no-store');
      try {
        await authenticate(request);
      } catch (error) {
        if (error instanceof DomainError && error.statusCode === 401)
          throw new SessionExpiredError();
        if (error instanceof DomainError) throw error;
        throw new DependencyUnavailableError();
      }
    });
    scope.get(
      '/me/weekly-recognitions',
      {
        schema: {
          ...common,
          summary: 'List finalized weekly recognitions of the current member',
          response: {
            ...common.response,
            200: {
              type: 'object',
              required: ['items'],
              properties: { items: { type: 'array', items: recognitionSchema } },
            },
          },
        },
      },
      async (request) => container.ownWeeklyRecognitions.list(requireActor(request)),
    );
    scope.get<{ Params: { recognitionId: string } }>(
      '/me/weekly-recognitions/:recognitionId',
      {
        schema: {
          ...common,
          summary: 'Get an owned weekly recognition',
          params,
        },
      },
      async (request) =>
        container.ownWeeklyRecognitions.get(requireActor(request), request.params.recognitionId),
    );
    scope.post<{ Params: { recognitionId: string } }>(
      '/me/weekly-recognitions/:recognitionId/opening',
      {
        schema: {
          ...common,
          summary: 'Record the first opening of an owned recognition',
          params,
        },
      },
      async (request) =>
        container.ownWeeklyRecognitions.open(requireActor(request), request.params.recognitionId),
    );
  });
}
