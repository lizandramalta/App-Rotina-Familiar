import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';

interface CreateFamilyBody {
  readonly creationGrant?: unknown;
  readonly creatorName?: unknown;
  readonly creatorNickname?: unknown;
  readonly name?: unknown;
  readonly timeZoneId?: unknown;
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
      creationGrant: { type: 'string' },
      creatorName: { type: 'string' },
      creatorNickname: { type: ['string', 'null'] },
      name: { type: 'string' },
      timeZoneId: { type: ['string', 'null'] },
    },
  },
  response: {
    201: {
      type: 'object',
      required: ['family', 'member', 'session'],
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
        session: sessionResponseSchema,
      },
    },
  },
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
}
