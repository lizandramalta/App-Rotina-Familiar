/**
 * Limites do ingresso por convite (RNF21, BA-29). Os valores vêm da
 * configuração validada; a Application só conhece a política.
 */
export interface InviteAttemptPolicy {
  /** Requisições por origem na janela, somando inspeção, ingresso e recuperação. */
  readonly originLimit: number;
  /** Tentativas de ingresso por convite na janela. */
  readonly inviteLimit: number;
  readonly windowMs: number;
}
