import { describe, it, expect } from 'vitest';
import { generateKeyPairSync, type KeyObject } from 'node:crypto';
import { validateConfiguration, ConfigurationError } from '../../src/bootstrap/configuration.js';

describe('Configuration & Fail-Fast Validation', () => {
  it('validates a correct minimal environment successfully', () => {
    const config = validateConfiguration({
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
    });

    expect(config.NODE_ENV).toBe('development');
    expect(config.PORT).toBe(3000);
    expect(config.HOST).toBe('0.0.0.0');
    expect(config.DATABASE_SCHEMA).toBe('app');
    expect(config.DATABASE_POOL_MIN).toBe(2);
    expect(config.DATABASE_POOL_MAX).toBe(10);
  });

  it('fails fast when DATABASE_URL is missing', () => {
    expect(() =>
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: '',
      }),
    ).toThrow(ConfigurationError);
  });

  it('fails fast when PORT is out of valid range', () => {
    expect(() =>
      validateConfiguration({
        PORT: 70000,
        DATABASE_URL: 'postgresql://localhost:5432/postgres',
      }),
    ).toThrow(ConfigurationError);
  });

  it('fails fast when NODE_ENV is production and secrets are insecurely short', () => {
    expect(() =>
      validateConfiguration({
        NODE_ENV: 'production',
        DATABASE_URL: 'postgresql://localhost:5432/postgres',
        SESSION_SECRET: 'short',
        INVITE_ENVELOPE_KEY: 'short',
      }),
    ).toThrow(ConfigurationError);
  });

  it('accepts valid 32+ character secrets in production', () => {
    const config = validateConfiguration({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgresql://postgres:pass@remote:5432/postgres?sslmode=require',
      SESSION_SECRET: 'a'.repeat(32),
      INVITE_ENVELOPE_KEY: 'b'.repeat(32),
      INVITE_LINK_BASE_URL: 'https://app.rotinafamiliar.example',
      // Production também exige as credenciais da Apple (SPEC-001).
      ...VALID_APPLE_CREDENTIALS,
    });

    expect(config.NODE_ENV).toBe('production');
    expect(config.SESSION_SECRET).toBe('a'.repeat(32));
  });
});

// Chave P-256 descartável gerada no runtime do teste, para não versionar
// material de chave em fixture.
const VALID_PEM = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  .privateKey.export({ format: 'pem', type: 'pkcs8' })
  .toString()
  .trim();

const PRODUCTION_BASE = {
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://postgres:pass@remote:5432/postgres',
  SESSION_SECRET: 'a'.repeat(32),
  INVITE_ENVELOPE_KEY: 'b'.repeat(32),
  INVITE_LINK_BASE_URL: 'https://app.rotinafamiliar.example',
};

const VALID_APPLE_CREDENTIALS = {
  APPLE_TEAM_ID: 'ABCDE12345',
  APPLE_KEY_ID: 'KEY1234567',
  APPLE_PRIVATE_KEY: VALID_PEM,
};

describe('Sign in with Apple configuration', () => {
  it('applies canonical Apple defaults when nothing is provided', () => {
    const config = validateConfiguration({
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
    });

    expect(config.APPLE_CLIENT_ID).toBe('com.lizandramalta.mutua');
    expect(config.APPLE_ISSUER).toBe('https://appleid.apple.com');
    expect(config.APPLE_JWKS_URL).toBe('https://appleid.apple.com/auth/keys');
    expect(config.APPLE_TOKEN_URL).toBe('https://appleid.apple.com/auth/token');
    expect(config.APPLE_TEAM_ID).toBeUndefined();
    expect(config.APPLE_KEY_ID).toBeUndefined();
    expect(config.APPLE_PRIVATE_KEY).toBeUndefined();
  });

  it.each(['development', 'test'] as const)('boots in %s without Apple credentials', (nodeEnv) => {
    expect(() =>
      validateConfiguration({
        NODE_ENV: nodeEnv,
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
      }),
    ).not.toThrow();
  });

  it('treats empty Apple placeholders in a local .env as not provided', () => {
    const config = validateConfiguration({
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
      APPLE_TEAM_ID: '',
      APPLE_KEY_ID: '   ',
      APPLE_PRIVATE_KEY: '',
    });

    expect(config.APPLE_TEAM_ID).toBeUndefined();
    expect(config.APPLE_KEY_ID).toBeUndefined();
    expect(config.APPLE_PRIVATE_KEY).toBeUndefined();
  });

  it.each([
    ['APPLE_TEAM_ID', 'TOOSHORT'],
    ['APPLE_TEAM_ID', 'WAYTOOLONG123'],
    ['APPLE_KEY_ID', 'SHORT'],
    ['APPLE_KEY_ID', 'HAS-DASH12'],
  ])('fails fast when %s has an invalid format (%s)', (key, value) => {
    expect(() =>
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
        [key]: value,
      }),
    ).toThrow(ConfigurationError);
  });

  it('fails fast when APPLE_PRIVATE_KEY is not a PEM private key', () => {
    expect(() =>
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
        APPLE_PRIVATE_KEY: 'not-a-pem-key',
      }),
    ).toThrow(ConfigurationError);
  });

  describe('APPLE_PRIVATE_KEY curve (ES256 requires P-256)', () => {
    const pemOf = (key: KeyObject): string =>
      key.export({ format: 'pem', type: 'pkcs8' }).toString();

    it.each(['secp384r1', 'secp521r1'])(
      'fails fast in production when the EC key uses the %s curve',
      (namedCurve) => {
        const wrongCurvePem = pemOf(generateKeyPairSync('ec', { namedCurve }).privateKey);

        expect(() =>
          validateConfiguration({
            ...PRODUCTION_BASE,
            ...VALID_APPLE_CREDENTIALS,
            APPLE_PRIVATE_KEY: wrongCurvePem,
          }),
        ).toThrow(ConfigurationError);
      },
    );

    it('fails fast in production when the key is RSA instead of EC', () => {
      const rsaPem = pemOf(generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey);

      expect(() =>
        validateConfiguration({
          ...PRODUCTION_BASE,
          ...VALID_APPLE_CREDENTIALS,
          APPLE_PRIVATE_KEY: rsaPem,
        }),
      ).toThrow(ConfigurationError);
    });

    it('names APPLE_PRIVATE_KEY as the offending variable', () => {
      const rsaPem = pemOf(generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey);

      try {
        validateConfiguration({
          ...PRODUCTION_BASE,
          ...VALID_APPLE_CREDENTIALS,
          APPLE_PRIVATE_KEY: rsaPem,
        });
        expect.unreachable('expected ConfigurationError');
      } catch (error) {
        const paths = (error as ConfigurationError).issues.map((issue) => issue.path.join('.'));
        expect(paths).toContain('APPLE_PRIVATE_KEY');
      }
    });

    it('accepts a P-256 key in production', () => {
      const config = validateConfiguration({
        ...PRODUCTION_BASE,
        ...VALID_APPLE_CREDENTIALS,
      });

      expect(config.APPLE_PRIVATE_KEY).toBe(VALID_PEM);
    });

    it('does not leak the key material when rejecting a wrong curve', () => {
      const wrongCurvePem = pemOf(
        generateKeyPairSync('ec', { namedCurve: 'secp384r1' }).privateKey,
      );

      try {
        validateConfiguration({
          ...PRODUCTION_BASE,
          ...VALID_APPLE_CREDENTIALS,
          APPLE_PRIVATE_KEY: wrongCurvePem,
        });
        expect.unreachable('expected ConfigurationError');
      } catch (error) {
        const body = wrongCurvePem.split('\n')[1] ?? '';
        expect((error as Error).message).not.toContain(body);
      }
    });
  });

  it.each(['APPLE_ISSUER', 'APPLE_JWKS_URL', 'APPLE_TOKEN_URL'])(
    'fails fast when %s is not a valid URL',
    (key) => {
      expect(() =>
        validateConfiguration({
          NODE_ENV: 'development',
          DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
          [key]: 'not-a-url',
        }),
      ).toThrow(ConfigurationError);
    },
  );

  it('accepts a PEM stored as a single line with literal escape sequences', () => {
    const config = validateConfiguration({
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
      APPLE_PRIVATE_KEY: VALID_PEM.replace(/\n/g, '\\n'),
    });

    expect(config.APPLE_PRIVATE_KEY).toBeDefined();
  });

  it('fails fast when the PEM delimiters are valid but the key material is corrupt', () => {
    const corruptPem = [
      '-----BEGIN PRIVATE KEY-----',
      'not-a-key',
      '-----END PRIVATE KEY-----',
    ].join('\n');

    expect(() =>
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
        APPLE_PRIVATE_KEY: corruptPem,
      }),
    ).toThrow(ConfigurationError);
  });

  it('fails fast when the PEM body is truncated mid-key', () => {
    const truncatedPem = `${VALID_PEM.slice(0, VALID_PEM.length - 40)}\n-----END PRIVATE KEY-----`;

    expect(() =>
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
        APPLE_PRIVATE_KEY: truncatedPem,
      }),
    ).toThrow(ConfigurationError);
  });

  it('validates production with complete Apple credentials', () => {
    const config = validateConfiguration({
      ...PRODUCTION_BASE,
      ...VALID_APPLE_CREDENTIALS,
    });

    expect(config.APPLE_TEAM_ID).toBe('ABCDE12345');
    expect(config.APPLE_KEY_ID).toBe('KEY1234567');
    expect(config.APPLE_PRIVATE_KEY).toBe(VALID_PEM);
  });

  it.each(['APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY'] as const)(
    'fails fast in production when %s is missing',
    (missingKey) => {
      const env: Record<string, unknown> = { ...PRODUCTION_BASE, ...VALID_APPLE_CREDENTIALS };
      delete env[missingKey];

      expect(() => validateConfiguration(env)).toThrow(ConfigurationError);
    },
  );

  it('reports every missing Apple credential at once in production', () => {
    try {
      validateConfiguration(PRODUCTION_BASE);
      expect.unreachable('expected ConfigurationError');
    } catch (error) {
      expect(error).toBeInstanceOf(ConfigurationError);
      const paths = (error as ConfigurationError).issues.map((issue) => issue.path.join('.'));
      expect(paths).toContain('APPLE_TEAM_ID');
      expect(paths).toContain('APPLE_KEY_ID');
      expect(paths).toContain('APPLE_PRIVATE_KEY');
    }
  });

  it.each([
    ['APPLE_ISSUER', 'https://example.com'],
    ['APPLE_JWKS_URL', 'https://example.com/auth/keys'],
    ['APPLE_TOKEN_URL', 'https://example.com/auth/token'],
  ])('fails fast in production when %s is not the canonical Apple endpoint', (key, url) => {
    expect(() =>
      validateConfiguration({
        ...PRODUCTION_BASE,
        ...VALID_APPLE_CREDENTIALS,
        [key]: url,
      }),
    ).toThrow(ConfigurationError);
  });

  it('accepts the canonical Apple endpoints stated explicitly in production', () => {
    const config = validateConfiguration({
      ...PRODUCTION_BASE,
      ...VALID_APPLE_CREDENTIALS,
      APPLE_ISSUER: 'https://appleid.apple.com',
      APPLE_JWKS_URL: 'https://appleid.apple.com/auth/keys',
      APPLE_TOKEN_URL: 'https://appleid.apple.com/auth/token',
    });

    expect(config.APPLE_ISSUER).toBe('https://appleid.apple.com');
  });

  it.each(['development', 'test'] as const)('allows a stub endpoint override in %s', (nodeEnv) => {
    const config = validateConfiguration({
      NODE_ENV: nodeEnv,
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
      APPLE_ISSUER: 'https://stub.local',
      APPLE_JWKS_URL: 'https://stub.local/auth/keys',
      APPLE_TOKEN_URL: 'https://stub.local/auth/token',
    });

    expect(config.APPLE_JWKS_URL).toBe('https://stub.local/auth/keys');
  });

  it('never echoes the private key value in validation error messages', () => {
    const secret = `-----BEGIN PRIVATE KEY-----\n${'S'.repeat(40)}`;

    try {
      validateConfiguration({
        NODE_ENV: 'development',
        DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
        APPLE_PRIVATE_KEY: secret,
      });
      expect.unreachable('expected ConfigurationError');
    } catch (error) {
      expect((error as Error).message).not.toContain('S'.repeat(40));
    }
  });
});

describe('Invite link base URL — SPEC-004', () => {
  const production = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://postgres:pass@remote:5432/postgres',
    SESSION_SECRET: 'a'.repeat(32),
    INVITE_ENVELOPE_KEY: 'b'.repeat(32),
    ...VALID_APPLE_CREDENTIALS,
  };

  it('defaults to the reserved .invalid domain outside production', () => {
    const config = validateConfiguration({
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres',
    });
    expect(config.INVITE_LINK_BASE_URL).toBe('https://example.invalid');
  });

  it('refuses the reserved placeholder domain in production', () => {
    expect(() => validateConfiguration(production)).toThrow(/INVITE_LINK_BASE_URL/);
  });

  it('accepts a real public URL in production', () => {
    const config = validateConfiguration({
      ...production,
      INVITE_LINK_BASE_URL: 'https://app.rotinafamiliar.example',
    });
    expect(config.INVITE_LINK_BASE_URL).toBe('https://app.rotinafamiliar.example');
  });
});
