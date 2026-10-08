import type { FastifyRequest } from 'fastify';
import type { ApplicationContainer } from '../../bootstrap/container.js';
import type { ActorContext } from '../../shared/application/actor-context.js';
import { AccessTokenInvalidError } from '../../modules/access/domain/access-errors.js';

declare module 'fastify' {
  interface FastifyRequest {
    /** Preenchido pelo hook de autenticação; ausente em rotas públicas. */
    actor?: ActorContext;
  }
}

const BEARER_PATTERN = /^Bearer\s+(\S+)$/i;

/**
 * Hook `onRequest` das rotas protegidas. Roda antes da leitura do corpo: uma
 * chamada sem sessão é recusada com 401 antes de qualquer validação de entrada.
 * A família e o papel saem da sessão persistida, nunca do request (RNF06/07).
 */
export function createAuthenticationHook(container: ApplicationContainer) {
  return async (request: FastifyRequest): Promise<void> => {
    const match = BEARER_PATTERN.exec(request.headers.authorization ?? '');

    if (match === null || match[1] === undefined) {
      throw new AccessTokenInvalidError();
    }

    request.actor = await container.authenticateSessionUseCase.execute(match[1]);
  };
}

/** Ator já autenticado pelo hook; falha alto se a rota esqueceu de registrá-lo. */
export function requireActor(request: FastifyRequest): ActorContext {
  if (request.actor === undefined) {
    throw new AccessTokenInvalidError();
  }

  return request.actor;
}
