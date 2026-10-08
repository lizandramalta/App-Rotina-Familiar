import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  ConsoleLogger,
  sanitizeLogContext,
} from '../../src/shared/infrastructure/observability/logger.js';

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

describe('Sign in with Apple log redaction', () => {
  it('redacts Apple proofs, credentials and installation proofs', () => {
    const sanitized = sanitizeLogContext({
      requestId: 'req-1',
      identityToken: 'apple-identity-jwt',
      authorizationCode: 'apple-authorization-code',
      rawNonce: 'generated-nonce',
      applePrivateKey: '-----BEGIN PRIVATE KEY-----secret',
      clientSecret: 'signed-apple-client-secret',
      installationProof: 'device-installation-proof',
      useCase: 'AuthenticateWithApple',
    }) as Record<string, unknown>;

    expect(sanitized.identityToken).toBe('[REDACTED]');
    expect(sanitized.authorizationCode).toBe('[REDACTED]');
    expect(sanitized.rawNonce).toBe('[REDACTED]');
    expect(sanitized.applePrivateKey).toBe('[REDACTED]');
    expect(sanitized.clientSecret).toBe('[REDACTED]');
    expect(sanitized.installationProof).toBe('[REDACTED]');
    expect(sanitized.requestId).toBe('req-1');
    expect(sanitized.useCase).toBe('AuthenticateWithApple');
  });

  it.each([
    'APPLE_PRIVATE_KEY',
    'apple_private_key',
    'identity_token',
    'authorization_code',
    'raw_nonce',
    'client_secret',
    'installation_proof',
    'x-installation-proof',
    'X-Installation-Proof',
  ])('redacts the %s spelling', (key) => {
    const sanitized = sanitizeLogContext({ [key]: 'secret-value' }) as Record<string, unknown>;

    expect(sanitized[key]).toBe('[REDACTED]');
  });

  it('redacts Apple proofs nested inside request payloads', () => {
    const sanitized = sanitizeLogContext({
      request: {
        headers: { 'x-installation-proof': 'device-proof' },
        body: { identityToken: 'apple-identity-jwt', rawNonce: 'nonce' },
      },
    }) as Record<string, unknown>;

    const request = sanitized.request as Record<string, unknown>;
    const headers = request.headers as Record<string, unknown>;
    const body = request.body as Record<string, unknown>;

    expect(headers['x-installation-proof']).toBe('[REDACTED]');
    expect(body.identityToken).toBe('[REDACTED]');
    expect(body.rawNonce).toBe('[REDACTED]');
  });

  it('redacts Apple proofs inside arrays', () => {
    const sanitized = sanitizeLogContext({
      attempts: [{ identityToken: 'first-jwt' }, { identityToken: 'second-jwt' }],
    }) as Record<string, unknown>;

    const attempts = sanitized.attempts as Record<string, unknown>[];

    expect(attempts[0]?.identityToken).toBe('[REDACTED]');
    expect(attempts[1]?.identityToken).toBe('[REDACTED]');
  });

  it('drops values beyond the depth limit instead of returning them unsanitized', () => {
    const sanitized = sanitizeLogContext({
      a: { b: { c: { d: { e: { f: { identityToken: 'apple-identity-jwt' } } } } } },
    });

    expect(JSON.stringify(sanitized)).not.toContain('apple-identity-jwt');
  });
});

describe('ConsoleLogger emitted output', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  /** Captura o JSON realmente escrito no console pelo logger. */
  function captureOutput(run: (logger: ConsoleLogger) => void, stream: 'log' | 'error' = 'log') {
    const spy = vi.spyOn(console, stream).mockImplementation(() => {});
    run(new ConsoleLogger('trace', { service: 'backend', applePrivateKey: 'pem-secret' }));

    expect(spy).toHaveBeenCalledTimes(1);
    return String(spy.mock.calls[0]?.[0]);
  }

  it('redacts sensitive default bindings in the emitted JSON', () => {
    const output = captureOutput((logger) => logger.info('boot completed'));

    expect(output).not.toContain('pem-secret');
    expect(JSON.parse(output).applePrivateKey).toBe('[REDACTED]');
    expect(JSON.parse(output).service).toBe('backend');
  });

  it('redacts sensitive default bindings inherited through child loggers', () => {
    const spy = vi.spyOn(console, 'log').mockImplementation(() => {});
    const parent = new ConsoleLogger('trace', { identityToken: 'apple-identity-jwt' });

    parent.child({ requestId: 'req-1' }).info('handling request');

    const output = String(spy.mock.calls[0]?.[0]);
    expect(output).not.toContain('apple-identity-jwt');
    expect(JSON.parse(output).identityToken).toBe('[REDACTED]');
    expect(JSON.parse(output).requestId).toBe('req-1');
  });

  it('redacts a secret interpolated into the log message', () => {
    const output = captureOutput((logger) =>
      logger.info('apple exchange failed for identityToken=eyJhbGciOiJSUzI1NiJ9.payload.signature'),
    );

    expect(output).not.toContain('eyJhbGciOiJSUzI1NiJ9.payload.signature');
    expect(JSON.parse(output).message).toContain('[REDACTED]');
  });

  it('redacts secrets carried in Error.message and Error.stack', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const logger = new ConsoleLogger('trace');

    logger.error('apple verification failed', new Error('rawNonce=super-secret-nonce'));

    const output = String(spy.mock.calls[0]?.[0]);
    expect(output).not.toContain('super-secret-nonce');

    const payload = JSON.parse(output) as { error: { message: string; stack: string } };
    expect(payload.error.message).toContain('[REDACTED]');
    expect(payload.error.stack).not.toContain('super-secret-nonce');
  });

  it('redacts a PEM private key leaked into an error message', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const pem = '-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEG\n-----END PRIVATE KEY-----';

    new ConsoleLogger('trace').error('signing failed', new Error(`key rejected: ${pem}`));

    const output = String(spy.mock.calls[0]?.[0]);
    expect(output).not.toContain('MIGTAgEAMBMGByqGSM49AgEG');
    expect(output).toContain('[REDACTED]');
  });

  it('redacts a non-Error thrown value carrying a secret', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});

    new ConsoleLogger('trace').error('apple exchange failed', 'client_secret=signed-jwt-value');

    const output = String(spy.mock.calls[0]?.[0]);
    expect(output).not.toContain('signed-jwt-value');
  });

  it('truncates primitive values nested beyond the depth limit', () => {
    const output = captureOutput((logger) =>
      logger.info('deep context', {
        a: { b: { c: { d: { e: { f: { g: 'deeply-nested-secret' } } } } } },
      }),
    );

    expect(output).not.toContain('deeply-nested-secret');
    expect(output).toContain('[TRUNCATED]');
  });

  it('keeps safe operational context intact', () => {
    const output = captureOutput((logger) =>
      logger.info('request completed', { requestId: 'req-1', durationMs: 12, statusCode: 200 }),
    );

    const payload = JSON.parse(output) as Record<string, unknown>;
    expect(payload.requestId).toBe('req-1');
    expect(payload.durationMs).toBe(12);
    expect(payload.statusCode).toBe(200);
    expect(payload.message).toBe('request completed');
  });
});

describe('sanitizeLogContext depth limit', () => {
  it('truncates a primitive nested beyond the depth limit', () => {
    const sanitized = sanitizeLogContext({
      a: { b: { c: { d: { e: { f: { token: 'deep-primitive-secret' } } } } } },
    });

    expect(JSON.stringify(sanitized)).not.toContain('deep-primitive-secret');
  });

  it('redacts a secret embedded in a plain string value', () => {
    const sanitized = sanitizeLogContext({
      detail: 'failed with identityToken=eyJhbGciOiJSUzI1NiJ9.payload.signature',
    }) as Record<string, unknown>;

    expect(sanitized.detail).not.toContain('eyJhbGciOiJSUzI1NiJ9.payload.signature');
  });
});

describe('ConsoleLogger quoted-value and Error.name redaction', () => {
  const SENTINEL = 'QA_SENTINEL_NONCE_5831';

  afterEach(() => {
    vi.restoreAllMocks();
  });

  function captureError(run: () => void): string {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    run();

    expect(spy).toHaveBeenCalledTimes(1);
    return String(spy.mock.calls[0]?.[0]);
  }

  it('redacts a single-quoted secret in Error.message and Error.stack', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(
        'apple verification failed',
        new Error(`rawNonce='${SENTINEL}'`),
      ),
    );

    expect(output).not.toContain(SENTINEL);

    const payload = JSON.parse(output) as { error: { message: string; stack: string } };
    expect(payload.error.message).toContain('[REDACTED]');
    expect(payload.error.stack).not.toContain(SENTINEL);
  });

  it('redacts a single-quoted secret in the log message', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(`clientSecret='${SENTINEL}'`),
    );

    expect(output).not.toContain(SENTINEL);
    expect((JSON.parse(output) as { message: string }).message).toContain('[REDACTED]');
  });

  it('redacts a secret carried in Error.name', () => {
    const error = new Error('apple exchange failed');
    error.name = `identityToken='${SENTINEL}'`;

    const output = captureError(() =>
      new ConsoleLogger('error').error('apple exchange failed', error),
    );

    expect(output).not.toContain(SENTINEL);
    expect((JSON.parse(output) as { error: { name: string } }).error.name).toContain('[REDACTED]');
  });

  it.each([
    ["rawNonce='%s'", 'single-quoted'],
    ['rawNonce="%s"', 'double-quoted'],
    ['rawNonce=%s', 'unquoted'],
    ["rawNonce: '%s'", 'single-quoted with colon separator'],
    ['rawNonce: "%s"', 'double-quoted with colon separator'],
    ['rawNonce: %s', 'unquoted with colon separator'],
  ])('redacts the %s form (%s)', (template) => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(template.replace('%s', SENTINEL)),
    );

    expect(output).not.toContain(SENTINEL);
  });

  it('redacts a single-quoted secret nested behind a harmless key', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(
        'apple verification failed',
        new Error(`context: rawNonce='${SENTINEL}'`),
      ),
    );

    expect(output).not.toContain(SENTINEL);
  });

  it('leaves an apostrophe in ordinary prose intact', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error("couldn't reach the family service, retryCount=3"),
    );

    const payload = JSON.parse(output) as { message: string };
    expect(payload.message).toBe("couldn't reach the family service, retryCount=3");
  });
});

describe('ConsoleLogger authorization scheme redaction', () => {
  const SENTINEL = 'QA_SENTINEL_NONCE_5831';

  afterEach(() => {
    vi.restoreAllMocks();
  });

  function captureError(run: () => void): string {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    run();

    expect(spy).toHaveBeenCalledTimes(1);
    return String(spy.mock.calls[0]?.[0]);
  }

  it('redacts the credential of an Authorization Bearer header in the message', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(`Authorization: Bearer ${SENTINEL}`),
    );

    expect(output).not.toContain(SENTINEL);
    expect((JSON.parse(output) as { message: string }).message).toContain('[REDACTED]');
  });

  it.each([
    ['Authorization: Bearer %s', 'colon separator, unquoted'],
    ['Authorization=Bearer %s', 'equals separator, unquoted'],
    ["Authorization: Bearer '%s'", 'single-quoted credential'],
    ['Authorization: Bearer "%s"', 'double-quoted credential'],
    ['authorization="Bearer %s"', 'whole scheme inside a quoted value'],
    ['authorization: bearer %s', 'lowercase scheme'],
    ['Authorization: Basic %s', 'Basic scheme'],
    ['Authorization: Digest %s', 'Digest scheme'],
    ['Authorization: SomeCustomScheme %s', 'unknown scheme after a sensitive key'],
    ['Authorization: %s', 'credential with no scheme'],
    ['invalid token: Bearer %s', 'scheme with no sensitive key before it'],
    ['failed with Authorization: Bearer %s on retry', 'scheme embedded mid-sentence'],
  ])('redacts the %s form (%s)', (template) => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(template.replace('%s', SENTINEL)),
    );

    expect(output).not.toContain(SENTINEL);
  });

  it('redacts an Authorization Bearer credential in Error.message and Error.stack', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(
        'apple exchange failed',
        new Error(`Authorization: Bearer ${SENTINEL}`),
      ),
    );

    expect(output).not.toContain(SENTINEL);

    const payload = JSON.parse(output) as { error: { message: string; stack: string } };
    expect(payload.error.message).toContain('[REDACTED]');
    expect(payload.error.stack).not.toContain(SENTINEL);
  });

  it('keeps the quoted value balanced after redacting the scheme inside it', () => {
    const output = captureError(() =>
      new ConsoleLogger('error').error(`authorization="Bearer ${SENTINEL}"`),
    );

    expect(output).not.toContain(SENTINEL);
    expect((JSON.parse(output) as { message: string }).message).toBe('authorization="[REDACTED]"');
  });

  it.each([
    'Basic validation failed for payload',
    'Token refresh scheduled in 30s',
    'Bearer token missing from request',
    'request completed statusCode=200 durationMs=12',
    'useCase=AuthenticateWithApple familyId=8f3c requestId=req-9',
  ])('leaves ordinary prose intact: %s', (message) => {
    const output = captureError(() => new ConsoleLogger('error').error(message));

    expect((JSON.parse(output) as { message: string }).message).toBe(message);
  });
});
