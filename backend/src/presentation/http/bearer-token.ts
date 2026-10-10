import type { FastifyRequest } from 'fastify';
import { SessionExpiredError } from '../../modules/access/domain/access-errors.js';

const BEARER_PREFIX = 'Bearer ';

/**
 * Lê o access token de `Authorization: Bearer <token>`.
 *
 * Header ausente e header malformado recebem o mesmo `SESSION_EXPIRED` das
 * rotas autenticadas (SPEC-001 §5.2): exigi-lo pelo schema responderia
 * `400 VALIDATION_FAILED`, que não é o código do contrato, e um erro distinto
 * para cada defeito diria ao chamador o que corrigir para adivinhar um token.
 */
export function readBearerToken(request: FastifyRequest): string {
  const header = request.headers.authorization;

  if (typeof header !== 'string' || !header.startsWith(BEARER_PREFIX)) {
    throw new SessionExpiredError();
  }

  const token = header.slice(BEARER_PREFIX.length).trim();

  if (token.length === 0) {
    throw new SessionExpiredError();
  }

  return token;
}
