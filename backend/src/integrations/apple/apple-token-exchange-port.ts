/**
 * Resultado da troca server-to-server do `authorizationCode` (SPEC-001 §5.1).
 *
 * `subject` é o `sub` do `id_token` devolvido pela Apple na troca. Ele existe
 * para ser conferido contra o `sub` do `identityToken` enviado pelo app: provas
 * de duas autenticações diferentes não podem ser combinadas.
 */
export interface AppleAuthorizationCodeExchange {
  readonly subject: string | undefined;
}

export interface AppleTokenExchangePort {
  exchangeAuthorizationCode(authorizationCode: string): Promise<AppleAuthorizationCodeExchange>;
}
