import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface UpdateOwnProfileBody {
  readonly name?: string | null;
  readonly nickname?: string | null;
  readonly photoMediaId?: string | null;
}

interface BadgeAwardParams {
  readonly awardId: string;
}

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

const nextTierSchema = {
  type: ['object', 'null'],
  properties: {
    code: { type: 'string' },
    requiredMissionCount: { type: 'integer' },
    remaining: { type: 'integer' },
  },
} as const;

/** Resposta canônica de `GetOwnProfile`/`UpdateOwnProfile` (SPEC-006 §5.2). */
const ownProfileResponseSchema = {
  type: 'object',
  required: [
    'memberId',
    'name',
    'familyName',
    'nickname',
    'photoMediaId',
    'totalParticipations',
    'nextTier',
  ],
  properties: {
    memberId: { type: 'string' },
    name: { type: 'string' },
    familyName: { type: 'string' },
    nickname: { type: ['string', 'null'] },
    photoMediaId: { type: ['string', 'null'] },
    totalParticipations: { type: 'integer', minimum: 0 },
    nextTier: nextTierSchema,
  },
} as const;

const badgeAwardSchema = {
  type: 'object',
  required: ['awardId', 'tier', 'requiredMissionCount', 'awardedAt'],
  properties: {
    awardId: { type: 'string' },
    tier: { type: 'string', enum: ['bronze', 'silver', 'gold', 'diamond'] },
    requiredMissionCount: { type: 'integer' },
    awardedAt: { type: 'string' },
  },
} as const;

const ownBadgesResponseSchema = {
  type: 'object',
  required: ['totalParticipations', 'nextTier', 'awards'],
  properties: {
    totalParticipations: { type: 'integer', minimum: 0 },
    nextTier: nextTierSchema,
    awards: { type: 'array', items: badgeAwardSchema },
  },
} as const;

const badgeContributionsResponseSchema = {
  type: 'object',
  required: ['awardId', 'tier', 'awardedAt', 'contributingMissions'],
  properties: {
    awardId: { type: 'string' },
    tier: { type: 'string', enum: ['bronze', 'silver', 'gold', 'diamond'] },
    awardedAt: { type: 'string' },
    contributingMissions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['missionId', 'title', 'completedAt'],
        properties: {
          missionId: { type: 'string' },
          title: { type: 'string' },
          completedAt: { type: ['string', 'null'] },
        },
      },
    },
  },
} as const;

/**
 * `PATCH /v1/me/profile` (SPEC-002 + SPEC-006): `name` (só adulto),
 * `nickname`/`photoMediaId` opcionais; os dois últimos nuláveis. Qualquer outro campo — inclusive `role`, `familyId`,
 * `kidsMode`, `isFamilyCreator`, `appleUserID` — é recusado como
 * `400 UNKNOWN_FIELD`, sem persistir.
 */
const updateOwnProfileSchema = {
  tags: ['Profile'],
  summary: 'Update the authenticated member name, nickname and/or photo',
  security: [{ bearerAuth: [] }],
  body: {
    type: 'object',
    additionalProperties: false,
    properties: {
      name: { type: ['string', 'null'] },
      nickname: { type: ['string', 'null'] },
      photoMediaId: { type: ['string', 'null'], format: 'uuid' },
    },
  },
  response: {
    200: ownProfileResponseSchema,
    400: problemResponseSchema,
    401: problemResponseSchema,
    403: problemResponseSchema,
    422: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

const getOwnProfileSchema = {
  tags: ['Profile'],
  summary: 'Get the authenticated member profile and badge progress',
  security: [{ bearerAuth: [] }],
  response: {
    200: ownProfileResponseSchema,
    401: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

const getOwnBadgesSchema = {
  tags: ['Profile'],
  summary: 'Get the authenticated member cumulative mission badges',
  security: [{ bearerAuth: [] }],
  response: {
    200: ownBadgesResponseSchema,
    401: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

const getBadgeContributionsSchema = {
  tags: ['Profile'],
  summary: 'Get the missions that contributed to one of the authenticated member badges',
  security: [{ bearerAuth: [] }],
  params: {
    type: 'object',
    required: ['awardId'],
    additionalProperties: false,
    properties: { awardId: { type: 'string' } },
  },
  response: {
    200: badgeContributionsResponseSchema,
    401: problemResponseSchema,
    404: problemResponseSchema,
    503: problemResponseSchema,
  },
} as const;

/** Rotas do módulo Profile. Registradas sob `/v1` (BA-20). */
export function registerProfileRoutes(
  app: FastifyInstance,
  container: ApplicationContainer,
  releaseChannel: 'full' | 'testflight' = 'full',
): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.get('/me/profile', { schema: getOwnProfileSchema }, async (request, reply) =>
      reply
        .status(200)
        .header('Cache-Control', 'no-store')
        .send(await container.getOwnProfileUseCase.execute(requireActor(request))),
    );

    scope.patch<{ Body: UpdateOwnProfileBody }>(
      '/me/profile',
      { schema: updateOwnProfileSchema },
      async (request, reply) => {
        const result = await container.updateOwnProfileUseCase.execute({
          actor: requireActor(request),
          name: request.body.name,
          nickname: request.body.nickname,
          photoMediaId: request.body.photoMediaId,
        });

        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );

    if (releaseChannel === 'full') {
      scope.get('/me/badges', { schema: getOwnBadgesSchema }, async (request, reply) =>
        reply
          .status(200)
          .header('Cache-Control', 'no-store')
          .send(await container.getOwnBadgesUseCase.execute(requireActor(request))),
      );

      scope.get<{ Params: BadgeAwardParams }>(
        '/me/badges/:awardId',
        { schema: getBadgeContributionsSchema },
        async (request, reply) =>
          reply
            .status(200)
            .header('Cache-Control', 'no-store')
            .send(
              await container.getBadgeContributionsUseCase.execute(
                requireActor(request),
                request.params.awardId,
              ),
            ),
      );
    }
  });
}
