/**
 * Verificador do `identityToken` da Apple (SPEC-001 §5.1).
 *
 * Os tokens são assinados de verdade com um par RSA descartável gerado no
 * runtime do teste, e a chave pública é servida como JWKS: um dublê que só
 * devolvesse `true` não provaria que a assinatura é conferida.
 */
import { describe, it, expect, beforeAll } from 'vitest';
import { createHash, createSign, generateKeyPairSync, type KeyObject } from 'node:crypto';
import {
  AppleTokenVerifier,
  AppleProofVerificationError,
} from '../../src/integrations/apple/apple-token-verifier.js';
import type {
  AppleJsonWebKey,
  AppleJwksPort,
} from '../../src/integrations/apple/apple-jwks-port.js';
import type { AppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';
import type { AppleTokenExchangePort } from '../../src/integrations/apple/apple-token-exchange-port.js';
import { AppleTokenExchangeError } from '../../src/integrations/apple/apple-token-client.js';

const KEY_ID = 'test-key-id';
const CLIENT_ID = 'com.lizandramalta.familyroutine';
const ISSUER = 'https://appleid.apple.com';
const APPLE_SUBJECT = '001234.abcdef0123456789.0000';
const RAW_NONCE = 'nonce-generated-by-the-app';
const NOW_MS = Date.parse('2026-10-08T12:00:00.000Z');

const appleConfig: AppleConfiguration = {
  clientId: CLIENT_ID,
  teamId: 'ABCDE12345',
  keyId: 'KEY1234567',
  privateKeyPem: undefined,
  issuer: ISSUER,
  jwksUrl: 'https://appleid.apple.com/auth/keys',
  tokenUrl: 'https://appleid.apple.com/auth/token',
};

let privateKey: KeyObject;
let jwk: AppleJsonWebKey;

const base64url = (value: object): string =>
  Buffer.from(JSON.stringify(value)).toString('base64url');

function signToken(payload: Record<string, unknown>, header: Record<string, unknown> = {}): string {
  const encodedHeader = base64url({ alg: 'RS256', kid: KEY_ID, typ: 'JWT', ...header });
  const encodedPayload = base64url(payload);

  const signer = createSign('RSA-SHA256');
  signer.update(`${encodedHeader}.${encodedPayload}`);
  signer.end();
  const signature = signer.sign(privateKey).toString('base64url');

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function validPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    iss: ISSUER,
    aud: CLIENT_ID,
    sub: APPLE_SUBJECT,
    exp: Math.floor(NOW_MS / 1000) + 600,
    iat: Math.floor(NOW_MS / 1000) - 10,
    nonce: createHash('sha256').update(RAW_NONCE).digest('hex'),
    ...overrides,
  };
}

function createJwks(keys: readonly AppleJsonWebKey[] = [jwk]): AppleJwksPort {
  return {
    findSigningKey: async (kid: string) => keys.find((key) => key.kid === kid),
  };
}

/**
 * Troca do `authorizationCode` que confirma o mesmo titular do identityToken.
 * É o caminho feliz; os casos de recusa e divergência têm dublês próprios.
 */
function createAcceptingExchange(subject: string = APPLE_SUBJECT): AppleTokenExchangePort {
  return { exchangeAuthorizationCode: async () => ({ subject }) };
}

function createVerifier(
  jwks: AppleJwksPort = createJwks(),
  tokenExchange: AppleTokenExchangePort = createAcceptingExchange(),
): AppleTokenVerifier {
  return new AppleTokenVerifier(appleConfig, jwks, tokenExchange, () => NOW_MS);
}

function proofFor(identityToken: string, overrides: Record<string, string> = {}) {
  return {
    identityToken,
    authorizationCode: 'apple-authorization-code',
    rawNonce: RAW_NONCE,
    ...overrides,
  };
}

describe('AppleTokenVerifier', () => {
  beforeAll(() => {
    const pair = generateKeyPairSync('rsa', { modulusLength: 2048 });
    privateKey = pair.privateKey;

    const exported = pair.publicKey.export({ format: 'jwk' }) as {
      kty: string;
      n: string;
      e: string;
    };

    jwk = {
      kid: KEY_ID,
      kty: exported.kty,
      alg: 'RS256',
      use: 'sig',
      n: exported.n,
      e: exported.e,
    };
  });

  describe('valid proof', () => {
    it('returns the Apple subject for a correctly signed token', async () => {
      const result = await createVerifier().verifyIdentityProof(
        proofFor(signToken(validPayload())),
      );

      expect(result.subject).toBe(APPLE_SUBJECT);
    });

    it('maps the optional email claims', async () => {
      const result = await createVerifier().verifyIdentityProof(
        proofFor(
          signToken(
            validPayload({
              email: 'creator@example.com',
              email_verified: 'true',
              is_private_email: false,
            }),
          ),
        ),
      );

      expect(result.email).toBe('creator@example.com');
      expect(result.isEmailVerified).toBe(true);
      expect(result.isPrivateEmail).toBe(false);
    });

    it('accepts the nonce encoded as base64url as well as hex', async () => {
      const nonce = createHash('sha256').update(RAW_NONCE).digest('base64url');

      const result = await createVerifier().verifyIdentityProof(
        proofFor(signToken(validPayload({ nonce }))),
      );

      expect(result.subject).toBe(APPLE_SUBJECT);
    });

    it('accepts an audience array that contains the client id', async () => {
      const result = await createVerifier().verifyIdentityProof(
        proofFor(signToken(validPayload({ aud: ['other.app', CLIENT_ID] }))),
      );

      expect(result.subject).toBe(APPLE_SUBJECT);
    });
  });

  describe('signature', () => {
    it('rejects a token signed by a different key', async () => {
      const foreign = generateKeyPairSync('rsa', { modulusLength: 2048 });
      const encodedHeader = base64url({ alg: 'RS256', kid: KEY_ID, typ: 'JWT' });
      const encodedPayload = base64url(validPayload());
      const signer = createSign('RSA-SHA256');
      signer.update(`${encodedHeader}.${encodedPayload}`);
      signer.end();
      const forged = `${encodedHeader}.${encodedPayload}.${signer
        .sign(foreign.privateKey)
        .toString('base64url')}`;

      await expect(createVerifier().verifyIdentityProof(proofFor(forged))).rejects.toThrow(
        'identity_token_signature_invalid',
      );
    });

    it('rejects a token whose payload was tampered with after signing', async () => {
      const token = signToken(validPayload());
      const [header, , signature] = token.split('.') as [string, string, string];
      const tampered = `${header}.${base64url(validPayload({ sub: 'attacker-subject' }))}.${signature}`;

      await expect(createVerifier().verifyIdentityProof(proofFor(tampered))).rejects.toThrow(
        'identity_token_signature_invalid',
      );
    });

    it('rejects an unsigned token that claims alg none', async () => {
      const encodedHeader = base64url({ alg: 'none', kid: KEY_ID });
      const token = `${encodedHeader}.${base64url(validPayload())}.`;

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_unexpected_algorithm',
      );
    });

    it('rejects a token whose kid is not published by Apple', async () => {
      const token = signToken(validPayload(), { kid: 'rotated-away-kid' });

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_unknown_kid',
      );
    });

    it('rejects a token with no kid in the header', async () => {
      const encodedHeader = Buffer.from(JSON.stringify({ alg: 'RS256' })).toString('base64url');
      const encodedPayload = base64url(validPayload());
      const signer = createSign('RSA-SHA256');
      signer.update(`${encodedHeader}.${encodedPayload}`);
      signer.end();
      const token = `${encodedHeader}.${encodedPayload}.${signer.sign(privateKey).toString('base64url')}`;

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_missing_kid',
      );
    });
  });

  describe('claims', () => {
    it('rejects an unexpected issuer', async () => {
      const token = signToken(validPayload({ iss: 'https://evil.example.com' }));

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_unexpected_issuer',
      );
    });

    it('rejects an audience that is not this app', async () => {
      const token = signToken(validPayload({ aud: 'com.someone.else' }));

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_unexpected_audience',
      );
    });

    it('rejects an expired token', async () => {
      const token = signToken(validPayload({ exp: Math.floor(NOW_MS / 1000) - 3600 }));

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_expired',
      );
    });

    it('rejects a token with no expiration claim', async () => {
      const payload = validPayload();
      delete payload.exp;

      await expect(
        createVerifier().verifyIdentityProof(proofFor(signToken(payload))),
      ).rejects.toThrow('identity_token_missing_expiration');
    });

    it('rejects a token issued in the future beyond the skew tolerance', async () => {
      const token = signToken(validPayload({ iat: Math.floor(NOW_MS / 1000) + 3600 }));

      await expect(createVerifier().verifyIdentityProof(proofFor(token))).rejects.toThrow(
        'identity_token_issued_in_the_future',
      );
    });

    it('rejects a token with no subject', async () => {
      const payload = validPayload();
      delete payload.sub;

      await expect(
        createVerifier().verifyIdentityProof(proofFor(signToken(payload))),
      ).rejects.toThrow('identity_token_missing_subject');
    });
  });

  describe('nonce', () => {
    it('rejects a rawNonce that does not match the token nonce', async () => {
      const token = signToken(validPayload());

      await expect(
        createVerifier().verifyIdentityProof(
          proofFor(token, { rawNonce: 'nonce-from-another-attempt' }),
        ),
      ).rejects.toThrow('identity_token_nonce_mismatch');
    });

    it('rejects a token with no nonce claim', async () => {
      const payload = validPayload();
      delete payload.nonce;

      await expect(
        createVerifier().verifyIdentityProof(proofFor(signToken(payload))),
      ).rejects.toThrow('identity_token_missing_nonce');
    });
  });

  describe('proof completeness', () => {
    it('rejects a proof with no authorizationCode', async () => {
      await expect(
        createVerifier().verifyIdentityProof(
          proofFor(signToken(validPayload()), { authorizationCode: '' }),
        ),
      ).rejects.toThrow('authorization_code_missing');
    });

    it('rejects a proof with no rawNonce', async () => {
      await expect(
        createVerifier().verifyIdentityProof(proofFor(signToken(validPayload()), { rawNonce: '' })),
      ).rejects.toThrow('raw_nonce_missing');
    });

    it('rejects an empty identityToken', async () => {
      await expect(createVerifier().verifyIdentityProof(proofFor(''))).rejects.toThrow(
        'identity_token_missing',
      );
    });

    it('rejects a malformed identityToken', async () => {
      await expect(createVerifier().verifyIdentityProof(proofFor('not.a-jwt'))).rejects.toThrow(
        'identity_token_malformed',
      );
    });

    it('rejects a token whose header is not decodable', async () => {
      await expect(createVerifier().verifyIdentityProof(proofFor('!!!.!!!.!!!'))).rejects.toThrow(
        AppleProofVerificationError,
      );
    });
  });
});

describe('AppleTokenVerifier authorization code exchange', () => {
  beforeAll(() => {
    // Reaproveita o par gerado no bloco anterior quando os dois rodam juntos;
    // isolado, gera o seu.
    if (privateKey === undefined) {
      const pair = generateKeyPairSync('rsa', { modulusLength: 2048 });
      privateKey = pair.privateKey;
      const exported = pair.publicKey.export({ format: 'jwk' }) as {
        kty: string;
        n: string;
        e: string;
      };
      jwk = {
        kid: KEY_ID,
        kty: exported.kty,
        alg: 'RS256',
        use: 'sig',
        n: exported.n,
        e: exported.e,
      };
    }
  });

  it('accepts the proof when Apple confirms the same subject', async () => {
    const verifier = createVerifier(createJwks(), createAcceptingExchange(APPLE_SUBJECT));

    const result = await verifier.verifyIdentityProof(proofFor(signToken(validPayload())));

    expect(result.subject).toBe(APPLE_SUBJECT);
  });

  it('sends the submitted authorizationCode to Apple for exchange', async () => {
    const seen: string[] = [];
    const verifier = createVerifier(createJwks(), {
      exchangeAuthorizationCode: async (code) => {
        seen.push(code);
        return { subject: APPLE_SUBJECT };
      },
    });

    await verifier.verifyIdentityProof(
      proofFor(signToken(validPayload()), { authorizationCode: 'code-from-the-app' }),
    );

    expect(seen).toEqual(['code-from-the-app']);
  });

  it('rejects a proof whose authorizationCode Apple refuses', async () => {
    const verifier = createVerifier(createJwks(), {
      exchangeAuthorizationCode: async () => {
        throw new AppleTokenExchangeError('apple_token_exchange_rejected');
      },
    });

    await expect(verifier.verifyIdentityProof(proofFor(signToken(validPayload())))).rejects.toThrow(
      'apple_token_exchange_rejected',
    );
  });

  it('rejects a proof when Apple is unreachable', async () => {
    const verifier = createVerifier(createJwks(), {
      exchangeAuthorizationCode: async () => {
        throw new AppleTokenExchangeError('apple_token_exchange_unreachable');
      },
    });

    await expect(verifier.verifyIdentityProof(proofFor(signToken(validPayload())))).rejects.toThrow(
      'apple_token_exchange_unreachable',
    );
  });

  it('rejects a proof whose exchanged subject differs from the identity token', async () => {
    const verifier = createVerifier(
      createJwks(),
      createAcceptingExchange('001234.someone.else.0000'),
    );

    await expect(verifier.verifyIdentityProof(proofFor(signToken(validPayload())))).rejects.toThrow(
      'authorization_code_subject_mismatch',
    );
  });

  it('rejects a proof when the exchange returns no subject', async () => {
    const verifier = createVerifier(createJwks(), {
      exchangeAuthorizationCode: async () => ({ subject: undefined }),
    });

    await expect(verifier.verifyIdentityProof(proofFor(signToken(validPayload())))).rejects.toThrow(
      'authorization_code_exchange_missing_subject',
    );
  });

  it('does not call Apple when the identity token is already invalid', async () => {
    let called = false;
    const verifier = createVerifier(createJwks(), {
      exchangeAuthorizationCode: async () => {
        called = true;
        return { subject: APPLE_SUBJECT };
      },
    });

    await expect(
      verifier.verifyIdentityProof(
        proofFor(signToken(validPayload({ iss: 'https://evil.example.com' }))),
      ),
    ).rejects.toThrow('identity_token_unexpected_issuer');
    expect(called).toBe(false);
  });
});
