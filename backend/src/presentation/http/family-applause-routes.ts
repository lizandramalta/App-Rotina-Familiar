import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';
import { FamilyApplauseService } from '../../modules/family/infrastructure/family-applause-service.js';

const dateRange = {
  type: 'object',
  required: ['startDate', 'endDate'],
  additionalProperties: false,
  properties: { startDate: { type: 'string' }, endDate: { type: 'string' } },
} as const;

const summaryResponse = {
  type: 'object',
  required: ['items'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['memberId', 'count', 'sentByMe'],
        properties: {
          memberId: { type: 'string', format: 'uuid' },
          count: { type: 'integer' },
          sentByMe: { type: 'boolean' },
        },
      },
    },
  },
} as const;

const receivedResponse = {
  type: 'object',
  required: ['items'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'senderNames', 'createdAt'],
        properties: {
          id: { type: 'string', format: 'uuid' },
          senderNames: { type: 'array', items: { type: 'string' } },
          createdAt: { type: 'string', format: 'date-time' },
        },
      },
    },
  },
} as const;

export function registerFamilyApplauseRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
): void {
  const service = new FamilyApplauseService(container.dbPool);
  const onRequest = createAuthenticationHook(container);
  app.get<{ Querystring: { startDate: string; endDate: string } }>(
    '/family/applause',
    {
      onRequest,
      schema: { tags: ['Family'], querystring: dateRange, response: { 200: summaryResponse } },
    },
    async (request) => {
      const actor = requireActor(request);
      const range = await container.getFamilyOverviewUseCase.execute(
        actor,
        request.query.startDate,
        request.query.endDate,
      );
      return service.summary(actor, range.startDate, range.endDate);
    },
  );

  app.post<{ Body: { recipientMemberId: string; startDate: string; endDate: string } }>(
    '/family/applause',
    {
      onRequest,
      schema: {
        tags: ['Family'],
        body: {
          type: 'object',
          required: ['recipientMemberId', 'startDate', 'endDate'],
          additionalProperties: false,
          properties: {
            recipientMemberId: { type: 'string' },
            startDate: { type: 'string' },
            endDate: { type: 'string' },
          },
        },
        response: {
          201: {
            type: 'object',
            required: ['id'],
            properties: { id: { type: 'string', format: 'uuid' } },
          },
        },
      },
    },
    async (request, reply) => {
      const actor = requireActor(request);
      const range = await container.getFamilyOverviewUseCase.execute(
        actor,
        request.body.startDate,
        request.body.endDate,
      );
      const result = await service.send(
        actor,
        request.body.recipientMemberId,
        range.startDate,
        range.endDate,
      );
      return reply.code(201).send(result);
    },
  );

  app.get(
    '/me/applause',
    { onRequest, schema: { tags: ['Profile'], response: { 200: receivedResponse } } },
    async (request) => service.received(requireActor(request)),
  );
  app.delete<{ Params: { id: string } }>(
    '/me/applause/:id',
    {
      onRequest,
      schema: {
        tags: ['Profile'],
        params: { type: 'object', required: ['id'], properties: { id: { type: 'string' } } },
      },
    },
    async (request, reply) => {
      await service.dismiss(requireActor(request), request.params.id);
      return reply.code(204).send();
    },
  );
  app.put<{ Body: { deviceToken: string; environment: string } }>(
    '/me/push-device',
    {
      onRequest,
      schema: {
        tags: ['Profile'],
        body: {
          type: 'object',
          required: ['deviceToken', 'environment'],
          additionalProperties: false,
          properties: { deviceToken: { type: 'string' }, environment: { type: 'string' } },
        },
      },
    },
    async (request, reply) => {
      await service.registerDevice(
        requireActor(request),
        request.body.deviceToken,
        request.body.environment,
      );
      return reply.code(204).send();
    },
  );
}
