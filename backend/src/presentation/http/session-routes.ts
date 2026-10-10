import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { readBearerToken } from './bearer-token.js';

/**
 * Schema de resposta de `GET /v1/me/session` (CA-07, SPEC-001 §5.2.2).
 *
 * `additionalProperties: false` é a trava de não vazamento na borda: mesmo que
 * a projeção da aplicação ganhe um campo novo, nada além destes quatro é
 * serializado para o cliente.
 */
const getCurrentSessionSchema = {
  response: {
    200: {
      type: 'object',
      required: ['memberId', 'familyId', 'role', 'isFamilyCreator'],
      additionalProperties: false,
      properties: {
        memberId: { type: 'string' },
        familyId: { type: 'string' },
        role: { type: 'string' },
        isFamilyCreator: { type: 'boolean' },
      },
    },
  },
} as const;

/** `DELETE /v1/me/session` responde sem corpo (CA-09, SPEC-001 §5.2.4). */
const revokeSessionSchema = {
  response: {
    204: { type: 'null' },
  },
} as const;

/** Rotas de sessão do titular. Registradas sob o prefixo `/v1` (BA-20). */
export function registerSessionRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.get('/me/session', { schema: getCurrentSessionSchema }, async (request, reply) => {
    const result = await container.getCurrentSessionUseCase.execute({
      accessToken: readBearerToken(request),
    });

    return reply.status(200).send(result);
  });

  app.delete('/me/session', { schema: revokeSessionSchema }, async (request, reply) => {
    await container.revokeSessionUseCase.execute({
      accessToken: readBearerToken(request),
    });

    return reply.status(204).send();
  });
}
