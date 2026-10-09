import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import type { SignInWithAppleResult } from '../../modules/access/application/sign-in-with-apple-dto.js';
import { PreviousSessionInvalidError } from '../../modules/access/domain/invite-errors.js';

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
  tags: ['Access'],
  summary: 'Authenticate with Sign in with Apple',
  description: 'Returns an active session or a short-lived family creation grant.',
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

const problemResponseSchema = {
  type: 'object',
  required: ['type', 'title', 'status', 'code', 'requestId'],
  properties: {
    type: { type: 'string' },
    title: { type: 'string' },
    status: { type: 'integer' },
    code: { type: 'string' },
    requestId: { type: 'string' },
    detail: { type: 'string' },
    fieldErrors: {
      type: 'object',
      additionalProperties: { type: 'array', items: { type: 'string' } },
    },
  },
} as const;

const sessionResultResponseSchema = {
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
  additionalProperties: false,
  properties: {
    sessionId: { type: 'string' },
    memberId: { type: 'string' },
    familyId: { type: 'string' },
    role: { type: 'string', enum: ['administrator', 'member', 'kids'] },
    isFamilyCreator: { type: 'boolean' },
    accessToken: { type: 'string' },
    accessTokenExpiresAt: { type: 'string' },
    refreshToken: { type: 'string' },
  },
} as const;

/**
 * Campos desconhecidos são recusados (`UNKNOWN_FIELD`): `familyId`, `memberId` e
 * papel nunca podem vir do cliente, porque derivam do convite (SPEC-005 CA-02).
 * Os limites de tamanho protegem o scrypt e o armazenamento de entradas absurdas.
 */
const inspectInviteSchema = {
  tags: ['Access'],
  summary: 'Inspect an invite link',
  description:
    'Neutral inspection: returns only whether the invite is available, with no identity, family, role or password data.',
  body: {
    type: 'object',
    required: ['token'],
    additionalProperties: false,
    properties: {
      token: { type: 'string', minLength: 1, maxLength: 256 },
    },
  },
  response: {
    200: {
      type: 'object',
      required: ['status'],
      additionalProperties: false,
      properties: { status: { type: 'string', enum: ['available'] } },
    },
    400: problemResponseSchema,
    404: problemResponseSchema,
    429: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

const joinByInviteSchema = {
  tags: ['Access'],
  summary: 'Join a family with an invite',
  description:
    'Consumes the invite once and opens the session of the invited profile. Family, member and role come only from the invite. Send a Bearer token only when replacing an active local session.',
  security: [{}, { bearerAuth: [] }],
  body: {
    type: 'object',
    required: [
      'token',
      'password',
      'attemptId',
      'attemptSecret',
      'installationProof',
      'switchConfirmed',
    ],
    additionalProperties: false,
    properties: {
      token: { type: 'string', minLength: 1, maxLength: 256 },
      password: { type: 'string', minLength: 1, maxLength: 64 },
      attemptId: { type: 'string', format: 'uuid' },
      attemptSecret: { type: 'string', minLength: 16, maxLength: 256 },
      installationProof: { type: 'string', minLength: 1, maxLength: 512 },
      switchConfirmed: { type: 'boolean' },
    },
  },
  response: {
    201: sessionResultResponseSchema,
    400: problemResponseSchema,
    401: problemResponseSchema,
    404: problemResponseSchema,
    409: problemResponseSchema,
    422: problemResponseSchema,
    429: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

const recoverInviteJoinSchema = {
  tags: ['Access'],
  summary: 'Recover a lost invite join result',
  description:
    'Returns the credentials of an already confirmed join for up to ten minutes. Requires the original attempt and installation proofs; never consumes the invite again.',
  body: {
    type: 'object',
    required: ['attemptId', 'attemptSecret', 'installationProof'],
    additionalProperties: false,
    properties: {
      attemptId: { type: 'string', format: 'uuid' },
      attemptSecret: { type: 'string', minLength: 16, maxLength: 256 },
      installationProof: { type: 'string', minLength: 1, maxLength: 512 },
    },
  },
  response: {
    200: sessionResultResponseSchema,
    400: problemResponseSchema,
    404: problemResponseSchema,
    429: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

interface InspectInviteBody {
  readonly token: string;
}

interface JoinByInviteBody {
  readonly token: string;
  readonly password: string;
  readonly attemptId: string;
  readonly attemptSecret: string;
  readonly installationProof: string;
  readonly switchConfirmed: boolean;
}

interface RecoverInviteJoinBody {
  readonly attemptId: string;
  readonly attemptSecret: string;
  readonly installationProof: string;
}

const BEARER_PATTERN = /^Bearer\s+(\S+)$/i;

/**
 * Bearer opcional do ingresso: ausente significa "sem sessão a substituir". Um
 * header presente porém malformado é credencial anterior inválida, e não se
 * ignora em silêncio — a troca seria feita sem a pessoa saber.
 */
function readOptionalBearer(header: string | undefined): string | undefined {
  if (header === undefined) {
    return undefined;
  }

  const match = BEARER_PATTERN.exec(header);
  if (match === null || match[1] === undefined) {
    throw new PreviousSessionInvalidError();
  }

  return match[1];
}

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

  app.post<{ Body: InspectInviteBody }>(
    '/access/invites/inspect',
    { schema: inspectInviteSchema },
    async (request, reply) => {
      const result = await container.inspectInviteUseCase.execute({
        token: request.body.token,
        origin: request.ip,
        requestId: request.id,
      });

      return reply.status(200).send(result);
    },
  );

  app.post<{ Body: JoinByInviteBody }>(
    '/access/invite-joins',
    { schema: joinByInviteSchema },
    async (request, reply) => {
      const session = await container.joinFamilyByInviteUseCase.execute({
        token: request.body.token,
        password: request.body.password,
        attemptId: request.body.attemptId,
        attemptSecret: request.body.attemptSecret,
        installationProof: request.body.installationProof,
        switchConfirmed: request.body.switchConfirmed,
        previousAccessToken: readOptionalBearer(request.headers.authorization),
        origin: request.ip,
        requestId: request.id,
      });

      return reply.status(201).send(session);
    },
  );

  app.post<{ Body: RecoverInviteJoinBody }>(
    '/access/invite-joins/recover',
    { schema: recoverInviteJoinSchema },
    async (request, reply) => {
      const session = await container.recoverInviteJoinUseCase.execute({
        attemptId: request.body.attemptId,
        attemptSecret: request.body.attemptSecret,
        installationProof: request.body.installationProof,
        origin: request.ip,
        requestId: request.id,
      });

      return reply.status(200).send(session);
    },
  );
}
