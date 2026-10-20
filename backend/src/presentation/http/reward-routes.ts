import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { DomainError } from '../../shared/domain/domain-error.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface RewardBody {
  readonly title?: unknown;
  readonly details?: unknown;
}

const predefinedSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'title', 'details', 'source'],
  properties: {
    id: { type: 'string', format: 'uuid' },
    title: { type: 'string' },
    details: { type: ['string', 'null'] },
    source: { type: 'string', enum: ['predefined'] },
  },
} as const;

const customSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'title', 'details', 'source', 'createdAt'],
  properties: {
    id: { type: 'string', format: 'uuid' },
    title: { type: 'string' },
    details: { type: ['string', 'null'] },
    source: { type: 'string', enum: ['custom'] },
    createdAt: { type: 'string', format: 'date-time' },
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
    fieldErrors: {
      type: 'object',
      additionalProperties: { type: 'array', items: { type: 'string' } },
    },
  },
} as const;

const errors = {
  400: problemSchema,
  401: problemSchema,
  403: problemSchema,
  422: problemSchema,
  503: problemSchema,
} as const;

/** Rotas do catálogo coletivo — SPEC-015 Fase 1 / SCRUM-80. */
export function registerRewardRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.get(
      '/reward-items',
      {
        preValidation: (request, _reply, done) => {
          const contentLength = Number(request.headers['content-length'] ?? 0);
          if (
            request.body !== undefined ||
            contentLength > 0 ||
            request.headers['transfer-encoding']
          ) {
            done(
              new DomainError({
                message: 'Reward catalog requests do not accept a body.',
                code: 'UNKNOWN_FIELD',
                statusCode: 400,
                fieldErrors: { body: ['UNKNOWN_FIELD'] },
              }),
            );
            return;
          }
          done();
        },
        schema: {
          tags: ['Rewards'],
          summary: 'List predefined and family reward items',
          security: [{ bearerAuth: [] }],
          querystring: { type: 'object', additionalProperties: false, properties: {} },
          response: {
            200: {
              type: 'object',
              additionalProperties: false,
              required: ['predefined', 'custom'],
              properties: {
                predefined: { type: 'array', items: predefinedSchema },
                custom: { type: 'array', items: customSchema },
              },
            },
            ...errors,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .send(await container.listRewardItemsUseCase.execute(requireActor(request))),
    );

    scope.post<{ Body: RewardBody }>(
      '/reward-items',
      {
        schema: {
          tags: ['Rewards'],
          summary: 'Add a family reward item',
          security: [{ bearerAuth: [] }],
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { title: { type: 'string' }, details: { type: 'string' } },
          },
          response: { 201: customSchema, ...errors },
        },
      },
      async (request, reply) =>
        reply.status(201).send(
          await container.addRewardItemUseCase.execute({
            actor: requireActor(request),
            title: request.body.title,
            details: request.body.details,
          }),
        ),
    );
  });
}
