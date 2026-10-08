import type { ActorContext } from '../../../shared/application/actor-context.js';

/**
 * Resolução do ator a partir do hash do access token. Leitura pura, sem
 * transação: papel, família e estado vêm do banco a cada chamada, sem cache que
 * prolongue permissão revogada (backend-architecture.md §8).
 */
export interface SessionLookupPort {
  findActorByAccessTokenHash(accessTokenHash: string, now: Date): Promise<ActorContext | undefined>;
}
