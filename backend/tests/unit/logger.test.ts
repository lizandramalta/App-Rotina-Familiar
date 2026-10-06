import { describe, it, expect } from 'vitest';
import { sanitizeLogContext } from '../../src/shared/infrastructure/observability/logger.js';

describe('Structured Logger Sanitization', () => {
  it('redacts sensitive headers and tokens', () => {
    const raw = {
      user: 'adult-1',
      authorization: 'Bearer secret-jwt-or-token',
      refreshToken: 'secret-refresh-token',
      password: 'super-secret-invite-password',
      installationSecret: 'secret-device-proof',
      nested: {
        appleProof: 'apple-jwt-identity-proof',
        safeField: 'ok-to-log',
      },
    };

    const sanitized = sanitizeLogContext(raw) as Record<string, unknown>;

    expect(sanitized.authorization).toBe('[REDACTED]');
    expect(sanitized.refreshToken).toBe('[REDACTED]');
    expect(sanitized.password).toBe('[REDACTED]');
    expect(sanitized.installationSecret).toBe('[REDACTED]');
    expect(sanitized.user).toBe('adult-1');

    const nested = sanitized.nested as Record<string, unknown>;
    expect(nested.appleProof).toBe('[REDACTED]');
    expect(nested.safeField).toBe('ok-to-log');
  });
});
