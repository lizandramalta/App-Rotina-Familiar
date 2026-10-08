import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface MemberParams {
  readonly memberId: string;
}

interface MemberQuery {
  readonly cursor?: string;
}

interface CreateMemberBody {
  readonly name?: unknown;
  readonly role?: unknown;
}

const memberProperties = {
  id: { type: 'string' },
  name: { type: 'string' },
  role: { type: 'string', enum: ['administrator', 'member', 'kids'] },
  isFamilyCreator: { type: 'boolean' },
  createdAt: { type: 'string' },
} as const;

const memberResponseSchema = {
  type: 'object',
  required: ['id', 'name', 'role', 'isFamilyCreator', 'createdAt'],
  properties: memberProperties,
} as const;

const memberDetailResponseSchema = {
  ...memberResponseSchema,
  required: [...memberResponseSchema.required, 'capabilities'],
  properties: {
    ...memberProperties,
    capabilities: {
      type: 'object',
      required: ['manageMembers'],
      properties: { manageMembers: { type: 'boolean' } },
    },
  },
} as const;

const listMembersResponseSchema = {
  type: 'object',
  required: ['items', 'nextCursor'],
  properties: {
    items: { type: 'array', items: memberResponseSchema },
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

/** Rotas de consulta e criação de membros — SPEC-003 Fase 1. */
export function registerMemberRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.get<{ Querystring: MemberQuery }>(
      '/family/members',
      {
        schema: {
          tags: ['Members'],
          summary: 'List family members',
          security: [{ bearerAuth: [] }],
          querystring: {
            type: 'object',
            additionalProperties: false,
            properties: { cursor: { type: 'string' } },
          },
          response: {
            200: listMembersResponseSchema,
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
            await container.listFamilyMembersUseCase.execute(
              requireActor(request),
              request.query.cursor,
            ),
          ),
    );

    scope.get<{ Params: MemberParams }>(
      '/family/members/:memberId',
      {
        schema: {
          tags: ['Members'],
          summary: 'Get a family member detail',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          response: {
            200: memberDetailResponseSchema,
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
            await container.getMemberDetailUseCase.execute(
              requireActor(request),
              request.params.memberId,
            ),
          ),
    );

    scope.post<{ Body: CreateMemberBody }>(
      '/family/members',
      {
        schema: {
          tags: ['Members'],
          summary: 'Create a family member without a session or invite',
          security: [{ bearerAuth: [] }],
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { name: {}, role: {} },
          },
          response: {
            201: memberResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const member = await container.createMemberUseCase.execute({
          actor: requireActor(request),
          name: request.body.name,
          role: request.body.role,
        });
        return reply
          .status(201)
          .header('Location', `/v1/family/members/${member.id}`)
          .header('Cache-Control', 'no-store')
          .send(member);
      },
    );
  });
}
