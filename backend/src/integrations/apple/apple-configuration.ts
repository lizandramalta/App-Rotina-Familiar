import { normalizePrivateKeyPem, type Configuration } from '../../bootstrap/configuration.js';

/**
 * Configuração da integração com o Sign in with Apple (BA-04, SPEC-001).
 *
 * `teamId`, `keyId` e `privateKeyPem` são opcionais porque development e test
 * autorizam boot sem credenciais reais. Em production o bootstrap já falha antes
 * de chegar aqui, mas o consumidor deve estreitar explicitamente antes de
 * assinar o client secret.
 */
export interface AppleConfiguration {
  readonly clientId: string;
  readonly teamId: string | undefined;
  readonly keyId: string | undefined;
  readonly privateKeyPem: string | undefined;
  readonly issuer: string;
  readonly jwksUrl: string;
  readonly tokenUrl: string;
}

export function createAppleConfiguration(config: Configuration): AppleConfiguration {
  return {
    clientId: config.APPLE_CLIENT_ID,
    teamId: config.APPLE_TEAM_ID,
    keyId: config.APPLE_KEY_ID,
    privateKeyPem:
      config.APPLE_PRIVATE_KEY === undefined
        ? undefined
        : normalizePrivateKeyPem(config.APPLE_PRIVATE_KEY),
    issuer: config.APPLE_ISSUER,
    jwksUrl: config.APPLE_JWKS_URL,
    tokenUrl: config.APPLE_TOKEN_URL,
  };
}
