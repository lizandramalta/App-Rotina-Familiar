import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import type { SignInWithAppleResult } from '../../modules/access/application/sign-in-with-apple-dto.js';

interface SignInWithAppleBody {
  readonly identityToken: string;
  readonly authorizationCode: string;
  readonly rawNonce: string;
}

interface SignInWithAppleHeaders {
  readonly 'x-installation-proof': string;
}

interface RefreshSessionBody {
  readonly refreshToken: string;
}

/**
 * Schema de entrada de `POST /v1/access/apple`.
 *
 * `additionalProperties` fica permitido de propósito: CA-06 exige que um
 * `familyId` enviado pelo cliente seja IGNORADO, não rejeitado. O handler lê
 * somente os três campos da prova, então nada além deles pode influenciar a
 * resposta.
 */
const signInWithAppleSchema = {
  headers: {
    type: 'object',
    required: ['x-installation-proof'],
    properties: {
      'x-installation-proof': { type: 'string', minLength: 1 },
    },
  },
  body: {
    type: 'object',
    required: ['identityToken', 'authorizationCode', 'rawNonce'],
    properties: {
      identityToken: { type: 'string', minLength: 1 },
      authorizationCode: { type: 'string', minLength: 1 },
      rawNonce: { type: 'string', minLength: 1 },
    },
  },
  response: {
    200: {
      // Os dois resultados possíveis (sessão e grant) compartilham o status 200
      // e têm corpos distintos, conforme SPEC-001 §5.2.1.
      oneOf: [
        {
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
        },
        {
          type: 'object',
          required: ['creationGrant', 'expiresAt'],
          properties: {
            creationGrant: { type: 'string' },
            expiresAt: { type: 'string' },
          },
        },
      ],
    },
  },
} as const;

/**
 * Schema de `POST /v1/access/refresh` (CA-08, SPEC-001 §5.2.3).
 *
 * A credencial vai no corpo e a prova de instalação no header, obrigatória: o
 * refresh token sozinho abriria sessão em qualquer instalação. A ausência do
 * header é defeito de requisição, logo `400 VALIDATION_FAILED`, e não 401.
 */
const refreshSessionSchema = {
  headers: {
    type: 'object',
    required: ['x-installation-proof'],
    properties: {
      'x-installation-proof': { type: 'string', minLength: 1 },
    },
  },
  body: {
    type: 'object',
    required: ['refreshToken'],
    properties: {
      refreshToken: { type: 'string', minLength: 1 },
    },
  },
  response: {
    200: {
      type: 'object',
      required: ['accessToken', 'accessTokenExpiresAt'],
      additionalProperties: false,
      properties: {
        accessToken: { type: 'string' },
        accessTokenExpiresAt: { type: 'string' },
      },
    },
  },
} as const;

/** Monta o corpo da resposta sem o discriminante interno `outcome`. */
function toResponseBody(result: SignInWithAppleResult): Record<string, unknown> {
  if (result.outcome === 'creationGrant') {
    return { creationGrant: result.creationGrant, expiresAt: result.expiresAt };
  }

  return {
    sessionId: result.sessionId,
    memberId: result.memberId,
    familyId: result.familyId,
    role: result.role,
    isFamilyCreator: result.isFamilyCreator,
    accessToken: result.accessToken,
    accessTokenExpiresAt: result.accessTokenExpiresAt,
    refreshToken: result.refreshToken,
  };
}

/** Rotas do módulo Access. Registradas sob o prefixo `/v1` (BA-20). */
export function registerAccessRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.post<{ Body: SignInWithAppleBody; Headers: SignInWithAppleHeaders }>(
    '/access/apple',
    { schema: signInWithAppleSchema },
    async (request, reply) => {
      const result = await container.signInWithAppleUseCase.execute({
        identityToken: request.body.identityToken,
        authorizationCode: request.body.authorizationCode,
        rawNonce: request.body.rawNonce,
        installationProof: request.headers['x-installation-proof'],
      });

      return reply.status(200).send(toResponseBody(result));
    },
  );

  app.post<{ Body: RefreshSessionBody; Headers: SignInWithAppleHeaders }>(
    '/access/refresh',
    { schema: refreshSessionSchema },
    async (request, reply) => {
      const result = await container.refreshSessionUseCase.execute({
        refreshToken: request.body.refreshToken,
        installationProof: request.headers['x-installation-proof'],
      });

      return reply.status(200).send(result);
    },
  );
}
