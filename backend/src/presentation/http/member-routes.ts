import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { ValidationError } from '../../shared/domain/domain-error.js';
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

interface UpdateMemberBody {
  readonly name?: unknown;
}
interface ChangeRoleBody {
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

const inviteCredentialsResponseSchema = {
  type: 'object',
  required: ['inviteId', 'link', 'password'],
  properties: {
    inviteId: { type: 'string' },
    link: { type: 'string' },
    password: { type: 'string' },
  },
} as const;

/** Rotas de consulta e criação de membros — SPEC-003 Fase 1. */
export function registerMemberRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
  releaseChannel: 'full' | 'testflight' = 'full',
): void {
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
        if (releaseChannel === 'testflight' && request.body.role === 'kids') {
          throw new ValidationError('Kids are not available in this release.', {
            role: ['MEMBER_ROLE_INVALID'],
          });
        }
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

    // SPEC-003 CA-02–06: only the full product exposes Kids name correction.
    if (releaseChannel === 'full') {
      scope.patch<{ Params: MemberParams; Body: UpdateMemberBody }>(
        '/family/members/:memberId',
        {
          schema: {
            tags: ['Members'],
            summary: 'Correct a Kids member administrative name as a family administrator',
            security: [{ bearerAuth: [] }],
            params: {
              type: 'object',
              required: ['memberId'],
              properties: { memberId: { type: 'string', format: 'uuid' } },
            },
            body: {
              type: 'object',
              additionalProperties: false,
              required: ['name'],
              properties: { name: {} },
            },
            response: {
              200: memberResponseSchema,
              400: problemResponseSchema,
              401: problemResponseSchema,
              403: problemResponseSchema,
              404: problemResponseSchema,
              422: problemResponseSchema,
              503: problemResponseSchema,
            },
          },
        },
        async (request, reply) => {
          return reply
            .status(200)
            .header('Cache-Control', 'no-store')
            .send(
              await container.updateMemberUseCase.execute(
                requireActor(request),
                request.params.memberId,
                request.body.name,
              ),
            );
        },
      );
    }

    scope.post<{ Params: MemberParams; Body: ChangeRoleBody }>(
      '/family/members/:memberId/role-changes',
      {
        schema: {
          tags: ['Members'],
          summary: 'Change a member role',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          body: {
            type: 'object',
            additionalProperties: false,
            required: ['role'],
            properties: { role: {} },
          },
          response: {
            200: memberResponseSchema,
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
        if (releaseChannel === 'testflight' && request.body.role === 'kids') {
          throw new ValidationError('Kids are not available in this release.', {
            role: ['MEMBER_ROLE_INVALID'],
          });
        }
        return reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(
            await container.changeMemberRoleUseCase.execute(
              requireActor(request),
              request.params.memberId,
              request.body.role,
            ),
          );
      },
    );

    scope.post(
      '/me/administration-exit',
      {
        preValidation: async (request) => {
          request.body ??= {};
        },
        schema: {
          tags: ['Members'],
          summary: 'Leave family administration',
          security: [{ bearerAuth: [] }],
          body: { type: 'object', additionalProperties: false, properties: {} },
          response: {
            200: memberResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            409: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(await container.leaveAdministrationUseCase.execute(requireActor(request))),
    );

    scope.delete<{ Params: MemberParams }>(
      '/family/members/:memberId',
      {
        schema: {
          tags: ['Members'],
          summary: 'Remove a member while preserving history',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          response: {
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
        await container.removeMemberUseCase.execute(requireActor(request), request.params.memberId);
        return reply.status(204).header('Cache-Control', 'no-store').send();
      },
    );

    // SPEC-004 Fase 1: o comando não aceita corpo; qualquer campo é UNKNOWN_FIELD.
    scope.post<{ Params: MemberParams }>(
      '/family/members/:memberId/invites',
      {
        // O comando não tem corpo: sem payload o schema `object` falharia, então
        // a ausência vira `{}` e qualquer campo enviado continua UNKNOWN_FIELD.
        preValidation: async (request) => {
          request.body ??= {};
        },
        schema: {
          tags: ['Members'],
          summary: 'Issue or reissue a member invite (transient link and password)',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          body: { type: 'object', additionalProperties: false, properties: {} },
          response: {
            201: inviteCredentialsResponseSchema,
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            409: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) =>
        reply
          .status(201)
          .header('Cache-Control', 'no-store')
          .send(
            await container.issueMemberInviteUseCase.execute({
              actor: requireActor(request),
              memberId: request.params.memberId,
              requestId: request.id,
            }),
          ),
    );
  });
}
