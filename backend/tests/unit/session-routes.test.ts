/**
 * `GET /v1/me/session` e `DELETE /v1/me/session` na borda HTTP
 * (SPEC-001 §5.2.2 e §5.2.4).
 *
 * Os casos de uso são dublês: o que está sob teste é o contrato de transporte —
 * leitura do Bearer, status, corpo de resposta e mapeamento de erro.
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import {
  SessionExpiredError,
  SessionRevokedError,
} from '../../src/modules/access/domain/access-errors.js';
import { createHttpTestContainer, type HttpTestContainer } from './support/http-container.js';

const ACCESS_TOKEN = 'opaque-access-token';

const CURRENT_SESSION = {
  memberId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  familyId: '11112222-3333-4444-5555-666677778888',
  role: 'administrator' as const,
  isFamilyCreator: true,
};

describe('Session routes (CA-07, CA-09)', () => {
  let app: FastifyInstance;
  let doubles: HttpTestContainer;

  beforeEach(() => {
    doubles = createHttpTestContainer();
    doubles.getCurrentSession.mockResolvedValue(CURRENT_SESSION);
    doubles.revokeSession.mockResolvedValue(undefined);

    app = buildHttpApp(doubles.container, doubles.config);
  });

  afterEach(async () => {
    await app.close();
  });

  function callSession(method: 'GET' | 'DELETE', headers: Record<string, string> = {}) {
    return app.inject({
      method,
      url: '/v1/me/session',
      headers: { authorization: `Bearer ${ACCESS_TOKEN}`, ...headers },
    });
  }

  describe('CA-07: GET /v1/me/session', () => {
    it('returns 200 with the current member, family, role and creator flag', async () => {
      const response = await callSession('GET');

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual(CURRENT_SESSION);
    });

    it('forwards the bearer token to the use case', async () => {
      await callSession('GET');

      expect(doubles.getCurrentSession).toHaveBeenCalledWith({ accessToken: ACCESS_TOKEN });
    });

    it('never includes a token, hash or secret in the body', async () => {
      doubles.getCurrentSession.mockResolvedValue({
        ...CURRENT_SESSION,
        // Um campo extra na projeção não pode chegar ao cliente.
        accessToken: 'leaked-access-token',
        refreshToken: 'leaked-refresh-token',
        installationProofHash: 'leaked-hash',
      });

      const response = await callSession('GET');

      expect(response.json()).toEqual(CURRENT_SESSION);
      expect(response.body).not.toContain('leaked-access-token');
      expect(response.body).not.toContain('leaked-refresh-token');
      expect(response.body).not.toContain('leaked-hash');
    });

    it('ignores a familyId forged by the client (RNF06)', async () => {
      const response = await app.inject({
        method: 'GET',
        url: '/v1/me/session?familyId=family-forged-by-client',
        headers: {
          authorization: `Bearer ${ACCESS_TOKEN}`,
          'x-family-id': 'family-forged-by-client',
        },
      });

      expect(response.statusCode).toBe(200);
      expect(response.json().familyId).toBe(CURRENT_SESSION.familyId);
      expect(doubles.getCurrentSession).toHaveBeenCalledWith({ accessToken: ACCESS_TOKEN });
    });
  });

  describe('CA-09: DELETE /v1/me/session', () => {
    it('returns 204 with no body', async () => {
      const response = await callSession('DELETE');

      expect(response.statusCode).toBe(204);
      expect(response.body).toBe('');
    });

    it('forwards the bearer token to the use case', async () => {
      await callSession('DELETE');

      expect(doubles.revokeSession).toHaveBeenCalledWith({ accessToken: ACCESS_TOKEN });
    });
  });

  describe('Authorization ausente ou malformado', () => {
    const malformed: Array<[string, Record<string, string>]> = [
      ['no Authorization header', {}],
      ['a header with no Bearer scheme', { authorization: ACCESS_TOKEN }],
      ['a Basic credential', { authorization: `Basic ${ACCESS_TOKEN}` }],
      ['a Bearer scheme with no token', { authorization: 'Bearer ' }],
      ['a Bearer scheme with a blank token', { authorization: 'Bearer    ' }],
      ['a lowercase bearer scheme', { authorization: `bearer ${ACCESS_TOKEN}` }],
    ];

    it.each(malformed)('rejects GET with %s as 401 SESSION_EXPIRED', async (_label, headers) => {
      const response = await app.inject({ method: 'GET', url: '/v1/me/session', headers });

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_EXPIRED');
      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(doubles.getCurrentSession).not.toHaveBeenCalled();
    });

    it.each(malformed)('rejects DELETE with %s as 401 SESSION_EXPIRED', async (_label, headers) => {
      const response = await app.inject({ method: 'DELETE', url: '/v1/me/session', headers });

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_EXPIRED');
      expect(doubles.revokeSession).not.toHaveBeenCalled();
    });
  });

  describe('mapeamento de erro de domínio', () => {
    it('maps SessionExpiredError to 401 SESSION_EXPIRED on GET', async () => {
      doubles.getCurrentSession.mockRejectedValue(new SessionExpiredError());

      const response = await callSession('GET');

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_EXPIRED');
      expect(response.json().requestId).toBeDefined();
    });

    it('maps SessionRevokedError to 401 SESSION_REVOKED on GET (CA-05)', async () => {
      doubles.getCurrentSession.mockRejectedValue(new SessionRevokedError());

      const response = await callSession('GET');

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_REVOKED');
      expect(response.headers['content-type']).toContain('application/problem+json');
    });

    it('maps SessionRevokedError to 401 SESSION_REVOKED on DELETE', async () => {
      doubles.revokeSession.mockRejectedValue(new SessionRevokedError());

      const response = await callSession('DELETE');

      expect(response.statusCode).toBe(401);
      expect(response.json().code).toBe('SESSION_REVOKED');
    });

    it('issues no credential in a rejection body', async () => {
      doubles.getCurrentSession.mockRejectedValue(new SessionRevokedError());

      const response = await callSession('GET');
      const body = response.json();

      expect(body).not.toHaveProperty('accessToken');
      expect(body).not.toHaveProperty('refreshToken');
      expect(response.body).not.toContain(ACCESS_TOKEN);
    });
  });
});
