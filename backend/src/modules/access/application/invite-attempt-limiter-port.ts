/**
 * Limite de tentativas do ingresso (RN46, RNF21).
 *
 * Cada chamada registra a tentativa e conta a janela no mesmo passo, de modo que
 * uma rajada concorrente não passa toda pelo "contar antes, registrar depois".
 * Fica fora da transação do ingresso: uma tentativa recusada precisa continuar
 * contada mesmo quando o comando faz rollback.
 */
export interface InviteAttemptLimiterPort {
  /**
   * Registra a tentativa e devolve `true` quando o total da janela, incluindo
   * esta, ultrapassa `limit`.
   */
  recordAndCheckExceeded(params: {
    readonly scope: 'invite' | 'origin';
    /** Identificador já derivado por hash; nunca o token ou o IP em claro. */
    readonly subjectHash: string;
    readonly limit: number;
    readonly now: Date;
    readonly windowMs: number;
  }): Promise<boolean>;
}
