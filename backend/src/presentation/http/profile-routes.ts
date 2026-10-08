import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface UpdateOwnProfileBody {
  readonly photoMediaId: string | null;
}

/**
 * `PATCH /v1/me/profile` no recorte da SPEC-002: só `photoMediaId`. Qualquer
 * outro campo — inclusive `familyId`, `memberId` e papel — é recusado como
 * `400 UNKNOWN_FIELD`; o apelido entra com a SPEC-006.
 */
const updateOwnProfileSchema = {
  body: {
    type: 'object',
    required: ['photoMediaId'],
    additionalProperties: false,
    properties: {
      photoMediaId: { type: ['string', 'null'], format: 'uuid' },
    },
  },
  response: {
    200: {
      type: 'object',
      required: ['photoMediaId'],
      properties: {
        photoMediaId: { type: ['string', 'null'] },
      },
    },
  },
} as const;

/** Rotas do módulo Profile. Registradas sob `/v1` (BA-20). */
export function registerProfileRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.patch<{ Body: UpdateOwnProfileBody }>(
      '/me/profile',
      { schema: updateOwnProfileSchema },
      async (request, reply) => {
        const result = await container.updateOwnProfileUseCase.execute({
          actor: requireActor(request),
          photoMediaId: request.body.photoMediaId,
        });

        return reply.status(200).header('Cache-Control', 'no-store').send(result);
      },
    );
  });
}
