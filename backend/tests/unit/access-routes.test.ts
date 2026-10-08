/**
 * `POST /v1/access/apple` na borda HTTP (SPEC-001 §5.2.1).
 *
 * O caso de uso é dublê: o que está sob teste é o contrato de transporte —
 * validação de entrada, status, corpo de resposta e mapeamento de erro.
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import { validateConfiguration, type Configuration } from '../../src/bootstrap/configuration.js';
import { createAppleConfiguration } from '../../src/integrations/apple/apple-configuration.js';
import type { ApplicationContainer } from '../../src/bootstrap/container.js';
import { AppleProofInvalidError } from '../../src/modules/access/domain/access-errors.js';
import { SystemClock } from '../../src/shared/application/clock.js';
import { ConsoleLogger } from '../../src/shared/infrastructure/observability/logger.js';

const VALID_BODY = {
  identityToken: 'apple-identity-token',
  authorizationCode: 'apple-authorization-code',
  rawNonce: 'app-generated-nonce',
};

const SESSION_RESULT = {
  outcome: 'session' as const,
  sessionId: 'e4f5a6b7-c8d9-0123-4567-89abcdef0123',
  memberId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  familyId: '11112222-3333-4444-5555-666677778888',
  role: 'administrator' as const,
  isFamilyCreator: true,
  accessToken: 'opaque-access-token',
  accessTokenExpiresAt: '2026-10-08T12:15:00.000Z',
  refreshToken: 'opaque-refresh-token',
};

const GRANT_RESULT = {
  outcome: 'creationGrant' as const,
  creationGrant: 'opaque-creation-grant',
  expiresAt: '2026-10-08T12:10:00.000Z',
};

describe('POST /v1/access/apple', () => {
  let app: FastifyInstance;
  let execute: ReturnType<typeof vi.fn>;
  let config: Configuration;

  beforeEach(() => {
    config = validateConfiguration({
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/postgres_test',
      LOG_LEVEL: 'fatal',
    });

    execute = vi.fn().mockResolvedValue(SESSION_RESULT);

    const container = {
      config,
      logger: new ConsoleLogger('fatal'),
      clock: new SystemClock(),
      dbPool: { checkHealth: vi.fn() } as unknown as ApplicationContainer['dbPool'],
      appleConfig: createAppleConfiguration(config),
      appleTokenVerifier: {
        verifyIdentityProof: vi.fn(),
      } as unknown as ApplicationContainer['appleTokenVerifier'],
      accessRepository: {} as unknown as ApplicationContainer['accessRepository'],
      transactionRunner: {
        run: vi.fn(),
        forFamily: vi.fn(),
      } as unknown as ApplicationContainer['transactionRunner'],
      signInWithAppleUseCase: {
        execute,
      } as unknown as ApplicationContainer['signInWithAppleUseCase'],
      dispose: vi.fn(),
    } as unknown as ApplicationContainer;

    app = buildHttpApp(container, config);
  });

  afterEach(async () => {
    await app.close();
  });

  function postApple(payload: unknown, headers: Record<string, string> = {}) {
    return app.inject({
      method: 'POST',
      url: '/v1/access/apple',
      headers: { 'x-installation-proof': 'installation-proof-value', ...headers },
      payload: payload as never,
    });
  }

  describe('CA-01: sessão do Criador', () => {
    it('returns 200 with the SessionResult body', async () => {
      const response = await postApple(VALID_BODY);

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual({
        sessionId: SESSION_RESULT.sessionId,
        memberId: SESSION_RESULT.memberId,
        familyId: SESSION_RESULT.familyId,
        role: 'administrator',
        isFamilyCreator: true,
        accessToken: SESSION_RESULT.accessToken,
        accessTokenExpiresAt: SESSION_RESULT.accessTokenExpiresAt,
        refreshToken: SESSION_RESULT.refreshToken,
      });
    });

    it('does not expose the internal outcome discriminator', async () => {
      const response = await postApple(VALID_BODY);

      expect(response.json()).not.toHaveProperty('outcome');
    });

    it('forwards the installation proof from the header to the use case', async () => {
      await postApple(VALID_BODY, { 'x-installation-proof': 'proof-abc' });

      expect(execute).toHaveBeenCalledWith({
        ...VALID_BODY,
        installationProof: 'proof-abc',
      });
    });
  });

  describe('CA-02: creationGrant', () => {
    it('returns 200 with the grant body when there is no linked family', async () => {
      execute.mockResolvedValue(GRANT_RESULT);

      const response = await postApple(VALID_BODY);

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual({
        creationGrant: GRANT_RESULT.creationGrant,
        expiresAt: GRANT_RESULT.expiresAt,
      });
    });
  });

  describe('CA-03: requisição inválida ou incompleta', () => {
    it.each(['identityToken', 'authorizationCode', 'rawNonce'])(
      'rejects a body with no %s with 400 VALIDATION_FAILED',
      async (missingField) => {
        const body: Record<string, unknown> = { ...VALID_BODY };
        delete body[missingField];

        const response = await postApple(body);

        expect(response.statusCode).toBe(400);
        expect(response.json().code).toBe('VALIDATION_FAILED');
        expect(execute).not.toHaveBeenCalled();
      },
    );

    it.each(['identityToken', 'authorizationCode', 'rawNonce'])(
      'rejects an empty %s with 400 VALIDATION_FAILED',
      async (emptyField) => {
        const response = await postApple({ ...VALID_BODY, [emptyField]: '' });

        expect(response.statusCode).toBe(400);
        expect(response.json().code).toBe('VALIDATION_FAILED');
        expect(execute).not.toHaveBeenCalled();
      },
    );

    it('rejects a request with no X-Installation-Proof header', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/access/apple',
        payload: VALID_BODY,
      });

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('VALIDATION_FAILED');
      expect(execute).not.toHaveBeenCalled();
    });

    it('rejects an empty body', async () => {
      const response = await postApple({});

      expect(response.statusCode).toBe(400);
      expect(execute).not.toHaveBeenCalled();
    });

    it('answers validation failures as application/problem+json with a requestId', async () => {
      const response = await postApple({});

      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json().requestId).toBeDefined();
      expect(response.json().status).toBe(400);
    });
  });

  describe('CA-04: prova Apple inválida', () => {
    it('maps AppleProofInvalidError to 401 APPLE_PROOF_INVALID', async () => {
      execute.mockRejectedValue(new AppleProofInvalidError());

      const response = await postApple(VALID_BODY);

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('APPLE_PROOF_INVALID');
      expect(response.headers['content-type']).toContain('application/problem+json');
    });

    it('issues no credential in the rejection body', async () => {
      execute.mockRejectedValue(new AppleProofInvalidError());

      const response = await postApple(VALID_BODY);
      const body = response.json();

      expect(body).not.toHaveProperty('accessToken');
      expect(body).not.toHaveProperty('refreshToken');
      expect(body).not.toHaveProperty('creationGrant');
    });

    it('does not echo the submitted proof in the error payload', async () => {
      execute.mockRejectedValue(new AppleProofInvalidError());

      const response = await postApple(VALID_BODY);

      expect(response.body).not.toContain(VALID_BODY.identityToken);
      expect(response.body).not.toContain(VALID_BODY.authorizationCode);
      expect(response.body).not.toContain(VALID_BODY.rawNonce);
    });
  });

  describe('CA-06: familyId nunca vem do cliente', () => {
    it('accepts the request and ignores a familyId sent in the body', async () => {
      const response = await postApple({
        ...VALID_BODY,
        familyId: 'family-forged-by-client',
      });

      expect(response.statusCode).toBe(200);
      // O comando entregue ao caso de uso não tem como transportar familyId.
      expect(execute).toHaveBeenCalledWith({
        ...VALID_BODY,
        installationProof: 'installation-proof-value',
      });
      expect(response.json().familyId).toBe(SESSION_RESULT.familyId);
    });

    it('ignores a familyId sent as a header', async () => {
      const response = await postApple(VALID_BODY, { 'x-family-id': 'family-forged-by-client' });

      expect(response.statusCode).toBe(200);
      expect(execute).toHaveBeenCalledWith({
        ...VALID_BODY,
        installationProof: 'installation-proof-value',
      });
      expect(response.json().familyId).toBe(SESSION_RESULT.familyId);
    });

    it('ignores a familyId sent as a query parameter', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/access/apple?familyId=family-forged-by-client',
        headers: { 'x-installation-proof': 'installation-proof-value' },
        payload: VALID_BODY,
      });

      expect(response.statusCode).toBe(200);
      expect(response.json().familyId).toBe(SESSION_RESULT.familyId);
    });
  });
});
