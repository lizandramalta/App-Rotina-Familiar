import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface CreateFamilyBody {
  readonly creationGrant?: unknown;
  readonly creatorName?: unknown;
  readonly creatorNickname?: unknown;
  readonly name?: unknown;
  readonly timeZoneId?: unknown;
  readonly initialMembers?: unknown;
  readonly creatorPhotoMediaId?: unknown;
}

interface UpdateFamilyBody {
  readonly name?: unknown;
}

interface CreateFamilyHeaders {
  readonly 'x-installation-proof': string;
}

const sessionResponseSchema = {
  type: 'object',
  required: [
    'sessionId',
    'memberId',
    'familyId',
    'role',
    'isFamilyCreator',
    'accessToken',
    'accessTokenExpiresAt',
    'refreshToken',
  ],
  properties: {
    sessionId: { type: 'string' },
    memberId: { type: 'string' },
    familyId: { type: 'string' },
    role: { type: 'string' },
    isFamilyCreator: { type: 'boolean' },
    accessToken: { type: 'string' },
    accessTokenExpiresAt: { type: 'string' },
    refreshToken: { type: 'string' },
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

/** OpenAPI-only shape; runtime validation keeps semantic errors in the use case. */
export const createFamilyBodyDocumentation = {
  type: 'object',
  required: ['creationGrant', 'creatorName', 'name'],
  additionalProperties: false,
  properties: {
    creationGrant: { type: 'string' },
    creatorName: { type: 'string' },
    creatorNickname: { type: ['string', 'null'] },
    name: { type: 'string' },
    timeZoneId: { type: 'string', default: 'America/Sao_Paulo' },
    initialMembers: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'role'],
        additionalProperties: false,
        properties: {
          name: { type: 'string' },
          role: { type: 'string', enum: ['administrator', 'member', 'kids'] },
        },
      },
    },
    creatorPhotoMediaId: { type: 'string', format: 'uuid' },
  },
} as const;

/**
 * Schema de `POST /v1/families` (SPEC-002 §5.2).
 *
 * Duas escolhas deliberadas:
 * - `additionalProperties: false` — `familyId`, papel e flag de Criador enviados
 *   pelo cliente são recusados com `400 UNKNOWN_FIELD`, não ignorados (CA-04).
 * - Nenhum campo é `required` e os tipos são permissivos: ausência e valores
 *   inválidos têm código de campo próprio e `422 VALIDATION_FAILED`, decididos
 *   pelo caso de uso. O grant ausente é `401`, não `400`.
 */
const createFamilySchema = {
  tags: ['Family'],
  summary: 'Create a family and its creator profile',
  description: 'Consumes a valid creation grant and returns the newly active session.',
  headers: {
    type: 'object',
    required: ['x-installation-proof'],
    properties: {
      'x-installation-proof': { type: 'string', minLength: 1 },
    },
  },
  body: {
    type: 'object',
    additionalProperties: false,
    properties: {
      creationGrant: {},
      creatorName: {},
      creatorNickname: {},
      name: {},
      timeZoneId: {},
      initialMembers: {},
      creatorPhotoMediaId: {},
    },
  },
  response: {
    201: {
      type: 'object',
      required: ['family', 'member', 'initialMembers', 'session'],
      properties: {
        family: {
          type: 'object',
          required: ['id', 'name', 'timeZoneId', 'createdAt'],
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            timeZoneId: { type: 'string' },
            createdAt: { type: 'string' },
          },
        },
        member: {
          type: 'object',
          required: ['id', 'name', 'nickname', 'role', 'isFamilyCreator'],
          properties: {
            id: { type: 'string' },
            name: { type: 'string' },
            nickname: { type: ['string', 'null'] },
            role: { type: 'string' },
            isFamilyCreator: { type: 'boolean' },
          },
        },
        initialMembers: {
          type: 'array',
          items: {
            type: 'object',
            required: ['id', 'name', 'role'],
            properties: {
              id: { type: 'string' },
              name: { type: 'string' },
              role: { type: 'string' },
            },
          },
        },
        session: sessionResponseSchema,
      },
    },
    400: problemResponseSchema,
    401: problemResponseSchema,
    422: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

interface TimeZoneChangeBody {
  readonly timeZoneId?: unknown;
  readonly application?: unknown;
}

const cycleLimitsSchema = {
  type: 'object',
  required: ['startsAt', 'endsAt', 'timeZoneId', 'isTransition'],
  properties: {
    startsAt: { type: 'string' },
    endsAt: { type: 'string' },
    timeZoneId: { type: 'string' },
    isTransition: { type: 'boolean' },
  },
} as const;

const familySettingsResponseSchema = {
  type: 'object',
  required: ['timeZoneId', 'scheduledTimeZoneChange', 'limits'],
  properties: {
    timeZoneId: { type: 'string' },
    scheduledTimeZoneChange: {
      type: ['object', 'null'],
      required: ['timeZoneId', 'effectiveAt'],
      properties: {
        timeZoneId: { type: 'string' },
        effectiveAt: { type: 'string' },
      },
    },
    limits: cycleLimitsSchema,
  },
} as const;

/**
 * Corpo de preview/confirmação (SPEC-002 §5.1). Como em `POST /v1/families`,
 * nenhum campo é `required` e os tipos são permissivos: o valor ausente ou
 * inválido recebe código de campo e `422 VALIDATION_FAILED` do caso de uso, e
 * `familyId`/papel enviados pelo cliente caem em `400 UNKNOWN_FIELD`.
 */
const timeZoneChangeBody = {
  type: 'object',
  additionalProperties: false,
  properties: {
    timeZoneId: {},
    application: {},
  },
} as const;

const previewTimeZoneChangeSchema = {
  body: timeZoneChangeBody,
  response: {
    200: {
      type: 'object',
      required: [
        'proposedTimeZoneId',
        'application',
        'effectiveAt',
        'effectiveLimits',
        'isTransition',
      ],
      properties: {
        proposedTimeZoneId: { type: 'string' },
        application: { type: 'string' },
        effectiveAt: { type: 'string' },
        effectiveLimits: cycleLimitsSchema,
        isTransition: { type: 'boolean' },
      },
    },
  },
} as const;

const changeTimeZoneSchema = {
  body: timeZoneChangeBody,
  response: { 200: familySettingsResponseSchema },
} as const;

/** Rotas do módulo Family. Registradas sob `/v1` (BA-20). */
export function registerFamilyRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.post<{ Body: CreateFamilyBody; Headers: CreateFamilyHeaders }>(
    '/families',
    { schema: createFamilySchema },
    async (request, reply) => {
      const result = await container.createFamilyUseCase.execute({
        creationGrant: request.body.creationGrant,
        creatorName: request.body.creatorName,
        creatorNickname: request.body.creatorNickname,
        name: request.body.name,
        timeZoneId: request.body.timeZoneId,
        initialMembers: request.body.initialMembers,
        creatorPhotoMediaId: request.body.creatorPhotoMediaId,
        installationProof: request.headers['x-installation-proof'],
      });

      // A resposta carrega os tokens da sessão: nunca pode ser guardada em cache.
      return reply
        .status(201)
        .header('Location', '/v1/family')
        .header('Cache-Control', 'no-store')
        .send(result);
    },
  );

  // Configurações exclusivas de Administrador: o papel vem da sessão (RNF07).
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    const familyResponse = {
      type: 'object',
      required: ['id', 'name', 'timeZoneId'],
      properties: {
        id: { type: 'string' },
        name: { type: 'string' },
        timeZoneId: { type: 'string' },
      },
    } as const;

    scope.get(
      '/family',
      {
        schema: {
          tags: ['Family'],
          summary: 'Get the current family',
          security: [{ bearerAuth: [] }],
          response: {
            200: familyResponse,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        const result = await container.getFamilyUseCase.execute(requireActor(request));
        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );

    scope.patch<{ Body: UpdateFamilyBody }>(
      '/family',
      {
        schema: {
          tags: ['Family'],
          summary: 'Update the family name',
          security: [{ bearerAuth: [] }],
          body: { type: 'object', additionalProperties: false, properties: { name: {} } },
          response: {
            200: familyResponse,
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
        const result = await container.updateFamilyUseCase.execute(
          requireActor(request),
          request.body.name,
        );
        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );

    scope.get('/family/settings', async (request, reply) => {
      const result = await container.getFamilySettingsUseCase.execute({
        actor: requireActor(request),
      });

      return reply.status(200).header('Cache-Control', 'no-store').send(result);
    });

    scope.post<{ Body: TimeZoneChangeBody }>(
      '/family/time-zone-changes/preview',
      { schema: previewTimeZoneChangeSchema },
      async (request, reply) => {
        const result = await container.previewFamilyTimeZoneChangeUseCase.execute({
          actor: requireActor(request),
          timeZoneId: request.body.timeZoneId,
          application: request.body.application,
        });

        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );

    scope.post<{ Body: TimeZoneChangeBody }>(
      '/family/time-zone-changes',
      { schema: changeTimeZoneSchema },
      async (request, reply) => {
        const result = await container.changeFamilyTimeZoneUseCase.execute({
          actor: requireActor(request),
          timeZoneId: request.body.timeZoneId,
          application: request.body.application,
        });

        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );
  });
}
