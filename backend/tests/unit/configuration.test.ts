import { describe, it, expect } from 'vitest';
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
    });

    expect(config.NODE_ENV).toBe('production');
    expect(config.SESSION_SECRET).toBe('a'.repeat(32));
  });
});
