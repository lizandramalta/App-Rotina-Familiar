import type { IssuedSession } from './session-issuer.js';

/**
 * Envelope criptografado das credenciais de um ingresso, guardado por dez
 * minutos para a recuperação (BA-11). Criptografia autenticada, com a chave fora
 * do banco; o `attemptId` entra como dado associado para que um envelope não
 * possa ser copiado para outra tentativa.
 */
export interface InviteJoinEnvelopePort {
  seal(attemptId: string, session: IssuedSession): string;

  /** Lança se o envelope foi adulterado ou pertence a outra tentativa. */
  open(attemptId: string, envelope: string): IssuedSession;
}
