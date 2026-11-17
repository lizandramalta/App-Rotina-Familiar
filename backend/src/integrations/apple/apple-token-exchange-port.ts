/**
 * Resultado da troca server-to-server do `authorizationCode` (SPEC-001 §5.1).
 *
 * `subject` é o `sub` do `id_token` devolvido pela Apple na troca. Ele existe
 * para ser conferido contra o `sub` do `identityToken` enviado pelo app: provas
 * de duas autenticações diferentes não podem ser combinadas.
 *
 * `refreshToken` e `accessToken` são os tokens Apple da mesma troca. O refresh
 * token é guardado cifrado para revogação na exclusão de conta (SPEC-001 Fase 4,
 * SPEC-022); nenhum dos dois pode entrar em log, resposta ou telemetria.
 */
export interface AppleAuthorizationCodeExchange {
  readonly subject: string | undefined;
  readonly refreshToken?: string;
  readonly accessToken?: string;
}

export interface AppleTokenExchangePort {
  exchangeAuthorizationCode(authorizationCode: string): Promise<AppleAuthorizationCodeExchange>;
}
