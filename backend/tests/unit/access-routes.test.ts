/**
 * `POST /v1/access/apple` na borda HTTP (SPEC-001 §5.2.1).
 *
 * O caso de uso é dublê: o que está sob teste é o contrato de transporte —
 * validação de entrada, status, corpo de resposta e mapeamento de erro.
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import {
  AppleProofInvalidError,
  SessionRevokedError,
} from '../../src/modules/access/domain/access-errors.js';
import { createHttpTestContainer, type HttpTestContainer } from './support/http-container.js';

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
  let doubles: HttpTestContainer;
  let execute: HttpTestContainer['signInWithApple'];

  beforeEach(() => {
    doubles = createHttpTestContainer();
    execute = doubles.signInWithApple;
    execute.mockResolvedValue(SESSION_RESULT);

    app = buildHttpApp(doubles.container, doubles.config);
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

  describe('no-store nas respostas que emitem credenciais', () => {
    it('answers the issued session with Cache-Control: no-store', async () => {
      const response = await postApple(VALID_BODY);

      expect(response.headers['cache-control']).toContain('no-store');
    });

    it('answers the issued creationGrant with Cache-Control: no-store', async () => {
      execute.mockResolvedValue(GRANT_RESULT);

      const response = await postApple(VALID_BODY);

      expect(response.headers['cache-control']).toContain('no-store');
    });

    it('answers a rejected proof with Cache-Control: no-store', async () => {
      execute.mockRejectedValue(new AppleProofInvalidError());

      const response = await postApple(VALID_BODY);

      expect(response.headers['cache-control']).toContain('no-store');
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

describe('POST /v1/access/refresh (CA-08)', () => {
  let app: FastifyInstance;
  let doubles: HttpTestContainer;

  const REFRESHED = {
    accessToken: 'new-opaque-access-token',
    accessTokenExpiresAt: '2026-10-08T12:30:00.000Z',
  };

  beforeEach(() => {
    doubles = createHttpTestContainer();
    doubles.refreshSession.mockResolvedValue(REFRESHED);

    app = buildHttpApp(doubles.container, doubles.config);
  });

  afterEach(async () => {
    await app.close();
  });

  function postRefresh(payload: unknown, headers: Record<string, string> = {}) {
    return app.inject({
      method: 'POST',
      url: '/v1/access/refresh',
      headers: { 'x-installation-proof': 'installation-proof-value', ...headers },
      payload: payload as never,
    });
  }

  describe('renovação bem-sucedida', () => {
    it('returns 200 with the new access token and its expiry', async () => {
      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual(REFRESHED);
    });

    it('forwards the refresh token from the body and the proof from the header', async () => {
      await postRefresh(
        { refreshToken: 'opaque-refresh-token' },
        {
          'x-installation-proof': 'proof-abc',
        },
      );

      expect(doubles.refreshSession).toHaveBeenCalledWith({
        refreshToken: 'opaque-refresh-token',
        installationProof: 'proof-abc',
      });
    });

    it('does not reissue the refresh token in the response', async () => {
      doubles.refreshSession.mockResolvedValue({
        ...REFRESHED,
        refreshToken: 'leaked-refresh-token',
      });

      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.json()).toEqual(REFRESHED);
      expect(response.body).not.toContain('leaked-refresh-token');
    });

    it('requires no Authorization header', async () => {
      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.statusCode).toBe(200);
    });
  });

  describe('requisição inválida', () => {
    it('rejects a body with no refreshToken with 400 VALIDATION_FAILED', async () => {
      const response = await postRefresh({});

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('VALIDATION_FAILED');
      expect(doubles.refreshSession).not.toHaveBeenCalled();
    });

    it('rejects an empty refreshToken with 400 VALIDATION_FAILED', async () => {
      const response = await postRefresh({ refreshToken: '' });

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('VALIDATION_FAILED');
      expect(doubles.refreshSession).not.toHaveBeenCalled();
    });

    it('rejects a request with no X-Installation-Proof header', async () => {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/access/refresh',
        payload: { refreshToken: 'opaque-refresh-token' },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('VALIDATION_FAILED');
      expect(doubles.refreshSession).not.toHaveBeenCalled();
    });

    it('answers validation failures as application/problem+json with a requestId', async () => {
      const response = await postRefresh({});

      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json().requestId).toBeDefined();
    });
  });

  describe('no-store na resposta que emite credencial', () => {
    it('answers the new access token with Cache-Control: no-store', async () => {
      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.headers['cache-control']).toContain('no-store');
    });

    it('answers a validation failure with Cache-Control: no-store', async () => {
      const response = await postRefresh({});

      expect(response.headers['cache-control']).toContain('no-store');
    });

    it('answers a revoked session with Cache-Control: no-store', async () => {
      doubles.refreshSession.mockRejectedValue(new SessionRevokedError());

      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.headers['cache-control']).toContain('no-store');
    });
  });

  describe('sessão encerrada ou prova divergente', () => {
    it('maps SessionRevokedError to 401 SESSION_REVOKED', async () => {
      doubles.refreshSession.mockRejectedValue(new SessionRevokedError());

      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_REVOKED');
      expect(response.headers['content-type']).toContain('application/problem+json');
    });

    it('issues no credential in the rejection body', async () => {
      doubles.refreshSession.mockRejectedValue(new SessionRevokedError());

      const response = await postRefresh({ refreshToken: 'opaque-refresh-token' });
      const body = response.json();

      expect(body).not.toHaveProperty('accessToken');
      expect(body).not.toHaveProperty('refreshToken');
    });

    it('does not echo the submitted credentials in the error payload', async () => {
      doubles.refreshSession.mockRejectedValue(new SessionRevokedError());

      const response = await postRefresh(
        { refreshToken: 'opaque-refresh-token' },
        {
          'x-installation-proof': 'secret-installation-proof',
        },
      );

      expect(response.body).not.toContain('opaque-refresh-token');
      expect(response.body).not.toContain('secret-installation-proof');
    });
  });
});
