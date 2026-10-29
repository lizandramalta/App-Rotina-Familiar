import { describe, it, expect } from 'vitest';
import { generateKeyPairSync } from 'node:crypto';
import { validateConfiguration } from '../../src/bootstrap/configuration.js';
import { createAppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';

// Chave P-256 descartável gerada no runtime do teste: a validação agora exige uma
// chave criptograficamente válida, e gerar evita versionar material de chave.
const MULTILINE_PEM = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  .privateKey.export({ format: 'pem', type: 'pkcs8' })
  .toString()
  .trim();
const ESCAPED_PEM = MULTILINE_PEM.replace(/\n/g, '\\n');

function buildConfig(overrides: Record<string, unknown> = {}) {
  return validateConfiguration({
    NODE_ENV: 'development',
    DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
    ...overrides,
  });
}

describe('Apple configuration mapper', () => {
  it('maps canonical Apple endpoints and client id by default', () => {
    const appleConfig = createAppleConfiguration(buildConfig());

    expect(appleConfig.clientId).toBe('com.lizandramalta.mutua');
    expect(appleConfig.issuer).toBe('https://appleid.apple.com');
    expect(appleConfig.jwksUrl).toBe('https://appleid.apple.com/auth/keys');
    expect(appleConfig.tokenUrl).toBe('https://appleid.apple.com/auth/token');
  });

  it('leaves credentials undefined when they are absent in development', () => {
    const appleConfig = createAppleConfiguration(buildConfig());

    expect(appleConfig.teamId).toBeUndefined();
    expect(appleConfig.keyId).toBeUndefined();
    expect(appleConfig.privateKeyPem).toBeUndefined();
  });

  it('maps provided credentials and overridden endpoints', () => {
    const appleConfig = createAppleConfiguration(
      buildConfig({
        APPLE_CLIENT_ID: 'com.example.app',
        APPLE_TEAM_ID: 'ABCDE12345',
        APPLE_KEY_ID: 'KEY1234567',
        APPLE_PRIVATE_KEY: MULTILINE_PEM,
        APPLE_JWKS_URL: 'https://stub.local/auth/keys',
      }),
    );

    expect(appleConfig.clientId).toBe('com.example.app');
    expect(appleConfig.teamId).toBe('ABCDE12345');
    expect(appleConfig.keyId).toBe('KEY1234567');
    expect(appleConfig.privateKeyPem).toBe(MULTILINE_PEM);
    expect(appleConfig.jwksUrl).toBe('https://stub.local/auth/keys');
  });

  it('normalizes literal escape sequences in the PEM into real line breaks', () => {
    const appleConfig = createAppleConfiguration(buildConfig({ APPLE_PRIVATE_KEY: ESCAPED_PEM }));

    expect(appleConfig.privateKeyPem).toBe(MULTILINE_PEM);
    expect(appleConfig.privateKeyPem).not.toContain('\\n');
  });

  it('normalizes a quoted single-line PEM coming from a .env file', () => {
    const appleConfig = createAppleConfiguration(
      buildConfig({ APPLE_PRIVATE_KEY: `"${ESCAPED_PEM}\\n"` }),
    );

    expect(appleConfig.privateKeyPem).toBe(MULTILINE_PEM);
  });
});
