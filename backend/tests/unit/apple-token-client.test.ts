/**
 * Troca server-to-server do `authorizationCode` (SPEC-001 §5.1).
 *
 * O `fetch` é injetado, então nada aqui toca a rede. A chave `.p8` é um par EC
 * P-256 descartável gerado no runtime, e o client secret assinado é VERIFICADO
 * com a chave pública correspondente: assim o teste prova a assinatura ES256,
 * não só o formato do JWT.
 */
import { describe, it, expect, beforeAll, vi } from 'vitest';
import { createPrivateKey, createVerify, generateKeyPairSync, type KeyObject } from 'node:crypto';
import {
  AppleTokenClient,
  AppleTokenExchangeError,
} from '../../src/integrations/apple/apple-token-client.js';
import type { AppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';
import { P256_CURVE_NAMES } from '../../src/bootstrap/configuration.js';
import { ConsoleLogger } from '../../src/shared/infrastructure/observability/logger.js';

const TEAM_ID = 'ABCDE12345';
const KEY_ID = 'KEY1234567';
const CLIENT_ID = 'com.lizandramalta.familyroutine';
const ISSUER = 'https://appleid.apple.com';
const TOKEN_URL = 'https://appleid.apple.com/auth/token';
const APPLE_SUBJECT = '001234.abcdef0123456789.0000';
const NOW_MS = Date.parse('2026-10-08T12:00:00.000Z');

let publicKey: KeyObject;
let privateKeyPem: string;

function configWith(overrides: Partial<AppleConfiguration> = {}): AppleConfiguration {
  return {
    clientId: CLIENT_ID,
    teamId: TEAM_ID,
    keyId: KEY_ID,
    privateKeyPem,
    issuer: ISSUER,
    jwksUrl: 'https://appleid.apple.com/auth/keys',
    tokenUrl: TOKEN_URL,
    ...overrides,
  };
}

/** `id_token` da resposta da Apple. Só o payload importa para a troca. */
function idTokenWithSubject(subject: string): string {
  const payload = Buffer.from(JSON.stringify({ sub: subject })).toString('base64url');
  return `header.${payload}.signature`;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function createClient(
  fetchImpl: typeof fetch,
  config: AppleConfiguration = configWith(),
): AppleTokenClient {
  return new AppleTokenClient(config, new ConsoleLogger('fatal'), () => NOW_MS, fetchImpl);
}

describe('AppleTokenClient', () => {
  beforeAll(() => {
    const pair = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    publicKey = pair.publicKey;
    privateKeyPem = pair.privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
  });

  describe('successful exchange', () => {
    it('returns the subject carried by the id_token', async () => {
      const fetchImpl = vi
        .fn()
        .mockResolvedValue(jsonResponse({ id_token: idTokenWithSubject(APPLE_SUBJECT) }));

      const result = await createClient(
        fetchImpl as unknown as typeof fetch,
      ).exchangeAuthorizationCode('code-from-the-app');

      expect(result.subject).toBe(APPLE_SUBJECT);
    });

    it('posts form-urlencoded credentials to the configured token URL', async () => {
      const fetchImpl = vi
        .fn()
        .mockResolvedValue(jsonResponse({ id_token: idTokenWithSubject(APPLE_SUBJECT) }));

      await createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode(
        'code-from-the-app',
      );

      const [url, init] = fetchImpl.mock.calls[0] as [string, RequestInit];
      const body = new URLSearchParams(String(init.body));

      expect(url).toBe(TOKEN_URL);
      expect(init.method).toBe('POST');
      expect((init.headers as Record<string, string>)['content-type']).toBe(
        'application/x-www-form-urlencoded',
      );
      expect(body.get('grant_type')).toBe('authorization_code');
      expect(body.get('client_id')).toBe(CLIENT_ID);
      expect(body.get('code')).toBe('code-from-the-app');
    });

    it('signs a client secret that verifies against the .p8 public key', async () => {
      const fetchImpl = vi
        .fn()
        .mockResolvedValue(jsonResponse({ id_token: idTokenWithSubject(APPLE_SUBJECT) }));

      await createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('code');

      const body = new URLSearchParams(
        String((fetchImpl.mock.calls[0] as [string, RequestInit])[1].body),
      );
      const clientSecret = body.get('client_secret') ?? '';
      const [header, payload, signature] = clientSecret.split('.') as [string, string, string];

      const verifier = createVerify('SHA256');
      verifier.update(`${header}.${payload}`);
      verifier.end();

      expect(
        verifier.verify(
          { key: publicKey, dsaEncoding: 'ieee-p1363' },
          Buffer.from(signature, 'base64url'),
        ),
      ).toBe(true);
    });

    it('emits a 64 byte JOSE signature, as ES256 requires', async () => {
      const fetchImpl = vi
        .fn()
        .mockResolvedValue(jsonResponse({ id_token: idTokenWithSubject(APPLE_SUBJECT) }));

      await createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('code');

      const body = new URLSearchParams(
        String((fetchImpl.mock.calls[0] as [string, RequestInit])[1].body),
      );
      const signature = (body.get('client_secret') ?? '').split('.')[2] ?? '';

      // P-256 produz r e s de 32 bytes cada; qualquer outra curva mudaria isso.
      expect(Buffer.from(signature, 'base64url')).toHaveLength(64);
    });

    it('builds the client secret claims required by Apple', async () => {
      const fetchImpl = vi
        .fn()
        .mockResolvedValue(jsonResponse({ id_token: idTokenWithSubject(APPLE_SUBJECT) }));

      await createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('code');

      const body = new URLSearchParams(
        String((fetchImpl.mock.calls[0] as [string, RequestInit])[1].body),
      );
      const [header, payload] = (body.get('client_secret') ?? '').split('.') as [string, string];

      const decode = (segment: string): Record<string, unknown> =>
        JSON.parse(Buffer.from(segment, 'base64url').toString('utf8')) as Record<string, unknown>;

      expect(decode(header)).toMatchObject({ alg: 'ES256', kid: KEY_ID });
      expect(decode(payload)).toMatchObject({
        iss: TEAM_ID,
        sub: CLIENT_ID,
        aud: ISSUER,
        iat: Math.floor(NOW_MS / 1000),
        exp: Math.floor(NOW_MS / 1000) + 300,
      });
    });
  });

  describe('rejections and failures', () => {
    it('fails when Apple answers invalid_grant', async () => {
      const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({ error: 'invalid_grant' }, 400));

      await expect(
        createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('stale-code'),
      ).rejects.toThrow('apple_token_exchange_rejected');
    });

    it('fails when the transport throws, such as a timeout', async () => {
      const fetchImpl = vi.fn().mockRejectedValue(new Error('The operation was aborted'));

      await expect(
        createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('code'),
      ).rejects.toThrow('apple_token_exchange_unreachable');
    });

    it('fails when the response body is not valid JSON', async () => {
      const fetchImpl = vi.fn().mockResolvedValue(new Response('not-json', { status: 200 }));

      await expect(
        createClient(fetchImpl as unknown as typeof fetch).exchangeAuthorizationCode('code'),
      ).rejects.toThrow('apple_token_exchange_response_not_decodable');
    });

    it('returns no subject when Apple omits the id_token', async () => {
      const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({ access_token: 'irrelevant' }));

      const result = await createClient(
        fetchImpl as unknown as typeof fetch,
      ).exchangeAuthorizationCode('code');

      expect(result.subject).toBeUndefined();
    });

    it.each([
      ['teamId', { teamId: undefined }],
      ['keyId', { keyId: undefined }],
      ['privateKeyPem', { privateKeyPem: undefined }],
    ])('fails closed when %s is not configured', async (_label, overrides) => {
      const fetchImpl = vi.fn();

      await expect(
        createClient(
          fetchImpl as unknown as typeof fetch,
          configWith(overrides as Partial<AppleConfiguration>),
        ).exchangeAuthorizationCode('code'),
      ).rejects.toBeInstanceOf(AppleTokenExchangeError);

      // Sem credencial não há nem tentativa de rede.
      expect(fetchImpl).not.toHaveBeenCalled();
    });

    it.each(['secp384r1', 'secp521r1'])(
      'fails closed when the EC key uses the %s curve instead of P-256',
      async (namedCurve) => {
        const wrongCurvePem = generateKeyPairSync('ec', { namedCurve })
          .privateKey.export({ format: 'pem', type: 'pkcs8' })
          .toString();
        const fetchImpl = vi.fn();

        await expect(
          createClient(
            fetchImpl as unknown as typeof fetch,
            configWith({ privateKeyPem: wrongCurvePem }),
          ).exchangeAuthorizationCode('code'),
        ).rejects.toThrow('apple_token_exchange_client_secret_key_not_p256');

        // A recusa precisa anteceder qualquer tentativa de rede.
        expect(fetchImpl).not.toHaveBeenCalled();
      },
    );

    it('accepts the curve name this runtime reports for a P-256 key', () => {
      // Guarda contra o conjunto de nomes aceitos divergir do que o Node/OpenSSL
      // desta máquina realmente reporta para P-256.
      const key = createPrivateKey({
        key: generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
          .privateKey.export({ format: 'pem', type: 'pkcs8' })
          .toString(),
        format: 'pem',
      });

      expect(P256_CURVE_NAMES.has(key.asymmetricKeyDetails?.namedCurve ?? '')).toBe(true);
    });

    it('fails closed when the configured private key is RSA instead of EC', async () => {
      const unusablePem = generateKeyPairSync('rsa', { modulusLength: 2048 })
        .privateKey.export({ format: 'pem', type: 'pkcs8' })
        .toString();
      const fetchImpl = vi.fn();

      await expect(
        createClient(
          fetchImpl as unknown as typeof fetch,
          configWith({ privateKeyPem: unusablePem }),
        ).exchangeAuthorizationCode('code'),
      ).rejects.toThrow('apple_token_exchange_client_secret_key_not_ec');
      expect(fetchImpl).not.toHaveBeenCalled();
    });

    it('fails closed when the configured private key is not decodable as PEM', async () => {
      const fetchImpl = vi.fn();

      await expect(
        createClient(
          fetchImpl as unknown as typeof fetch,
          configWith({
            privateKeyPem: '-----BEGIN PRIVATE KEY-----\nbroken\n-----END PRIVATE KEY-----',
          }),
        ).exchangeAuthorizationCode('code'),
      ).rejects.toThrow('apple_token_exchange_client_secret_not_signable');
      expect(fetchImpl).not.toHaveBeenCalled();
    });
  });

  describe('secret hygiene', () => {
    it('never puts the client secret or the code in the thrown error', async () => {
      const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({ error: 'invalid_grant' }, 400));

      const error = await createClient(fetchImpl as unknown as typeof fetch)
        .exchangeAuthorizationCode('secret-authorization-code')
        .catch((err: unknown) => err);

      expect((error as Error).message).not.toContain('secret-authorization-code');
      expect((error as Error).message).not.toContain(privateKeyPem.slice(40, 80));
    });
  });
});
