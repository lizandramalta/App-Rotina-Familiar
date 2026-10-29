/**
 * Chave pública publicada pela Apple em `APPLE_JWKS_URL`, usada para conferir a
 * assinatura do `identityToken` (SPEC-001).
 */
export interface AppleJsonWebKey {
  readonly kid: string;
  readonly kty: string;
  readonly alg: string;
  readonly use?: string;
  readonly n: string;
  readonly e: string;
}

export interface AppleJwksPort {
  /**
   * Retorna a chave correspondente ao `kid` do header do `identityToken`, ou
   * `undefined` quando a Apple não publica esse `kid`.
   */
  findSigningKey(kid: string): Promise<AppleJsonWebKey | undefined>;
}
