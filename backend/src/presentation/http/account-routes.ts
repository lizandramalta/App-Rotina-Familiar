import type { FastifyInstance } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import { createAuthenticationHook, requireActor } from './authentication.js';

interface MemberParams {
  readonly memberId: string;
}

interface DeleteOwnAccountBody {
  readonly apple?: {
    readonly identityToken: string;
    readonly authorizationCode: string;
    readonly rawNonce: string;
  };
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

/**
 * Prova Apple da reserva do Criador sem token guardado (SPEC-022 §5.1). Mesmos
 * campos de `POST /v1/access/apple`; nunca registrados em log (RNF16).
 */
const appleProofSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['identityToken', 'authorizationCode', 'rawNonce'],
  properties: {
    identityToken: { type: 'string', minLength: 1 },
    authorizationCode: { type: 'string', minLength: 1 },
    rawNonce: { type: 'string', minLength: 1 },
  },
} as const;

/** Rotas de exclusão de conta — SPEC-022 (UC20). Registradas sob `/v1`. */
export function registerAccountRoutes(app: FastifyInstance, container: ApplicationContainer): void {
  app.register(async (scope) => {
    scope.addHook('onRequest', createAuthenticationHook(container));

    scope.post<{ Body: DeleteOwnAccountBody }>(
      '/me/account-deletion',
      {
        // Corpo opcional: a ausência vira `{}` e campos fora do schema, como
        // `memberId` ou `familyId`, continuam `400 UNKNOWN_FIELD` (CA-06).
        preValidation: async (request) => {
          request.body ??= {};
        },
        schema: {
          tags: ['Account'],
          summary: 'Delete the authenticated account (the family when the actor is its creator)',
          description:
            'Immediate and irreversible (SPEC-022). A non-creator profile is anonymized and its history is kept as "Membro removido". ' +
            'The family creator deletes the whole family; without a stored Apple refresh token the request must carry a fresh Apple proof, ' +
            'otherwise it answers 422 APPLE_PROOF_REQUIRED.',
          security: [{ bearerAuth: [] }],
          body: {
            type: 'object',
            additionalProperties: false,
            properties: { apple: appleProofSchema },
          },
          response: {
            204: {
              type: 'null',
              description: 'Account deleted; no session of the account remains valid.',
            },
            400: problemResponseSchema,
            401: problemResponseSchema,
            422: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        await container.deleteOwnAccountUseCase.execute(requireActor(request), {
          apple: request.body.apple,
        });
        return reply.status(204).header('Cache-Control', 'no-store').send();
      },
    );

    scope.post<{ Params: MemberParams }>(
      '/family/members/:memberId/account-deletion',
      {
        preValidation: async (request) => {
          request.body ??= {};
        },
        schema: {
          tags: ['Account'],
          summary: 'Delete a Kids account and its personal data as a family administrator',
          description:
            'Same effects as a non-creator self deletion (SPEC-022 CA-16). Only administrators, and only for an active Kids profile of the same family.',
          security: [{ bearerAuth: [] }],
          params: {
            type: 'object',
            required: ['memberId'],
            properties: { memberId: { type: 'string', format: 'uuid' } },
          },
          body: { type: 'object', additionalProperties: false, properties: {} },
          response: {
            204: { type: 'null', description: 'Kids account deleted.' },
            400: problemResponseSchema,
            401: problemResponseSchema,
            403: problemResponseSchema,
            404: problemResponseSchema,
            503: problemResponseSchema,
          },
        },
      },
      async (request, reply) => {
        await container.deleteKidsAccountUseCase.execute(
          requireActor(request),
          request.params.memberId,
        );
        return reply.status(204).header('Cache-Control', 'no-store').send();
      },
    );
  });
}
