/** Tipo do token enviado a `POST /auth/revoke` (`token_type_hint` da Apple). */
export type AppleTokenTypeHint = 'refresh_token' | 'access_token';

/**
 * Revogação de tokens Apple quando o Criador exclui a conta (RN70, RF73,
 * SPEC-022 CA-13). Falha de rede, recusa ou credencial ausente é erro: quem
 * chama decide reagendar, sem nunca desfazer a exclusão.
 */
export interface AppleTokenRevocationPort {
  revokeToken(token: string, tokenTypeHint: AppleTokenTypeHint): Promise<void>;
}
