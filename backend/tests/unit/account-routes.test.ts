/**
 * Contrato HTTP da exclusão de conta — SPEC-022 §5.2, CA-06, CA-10, CA-16–CA-18.
 * Os casos de uso são dublês: o que está sob teste é schema, status, segurança e
 * documentação OpenAPI.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { AppleProofRequiredError } from '../../src/modules/account/domain/account-errors.js';
import { ActionNotAllowedError, NotFoundError } from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const KIDS_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const PROOF = { identityToken: 'jwt', authorizationCode: 'code', rawNonce: 'nonce' };

describe('Account routes — SPEC-022', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.deleteOwnAccount.execute.mockResolvedValue(undefined);
    test.deleteKidsAccount.execute.mockResolvedValue(undefined);
  });

  afterEach(async () => test.app.close());

  describe('POST /v1/me/account-deletion', () => {
    it('CA-01 accepts an empty body and targets only the authenticated actor', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/me/account-deletion',
        headers: AUTH,
      });

      expect(response.statusCode).toBe(204);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(test.deleteOwnAccount.execute).toHaveBeenCalledWith(TEST_ACTOR, { apple: undefined });
    });

    it('forwards the fallback Apple proof with its nonce', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/me/account-deletion',
        headers: AUTH,
        payload: { apple: PROOF },
      });

      expect(response.statusCode).toBe(204);
      expect(test.deleteOwnAccount.execute).toHaveBeenCalledWith(TEST_ACTOR, { apple: PROOF });
    });

    it.each([
      { memberId: KIDS_ID },
      { familyId: KIDS_ID },
      { role: 'kids' },
      { familyName: 'Silva' },
    ])('CA-06 refuses protected or unknown field %o with UNKNOWN_FIELD', async (payload) => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/me/account-deletion',
        headers: AUTH,
        payload,
      });

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('UNKNOWN_FIELD');
      expect(test.deleteOwnAccount.execute).not.toHaveBeenCalled();
    });

    it('refuses an incomplete Apple proof', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/me/account-deletion',
        headers: AUTH,
        payload: { apple: { identityToken: 'jwt', authorizationCode: 'code' } },
      });

      expect(response.statusCode).toBe(400);
      expect(test.deleteOwnAccount.execute).not.toHaveBeenCalled();
    });

    it('CA-10 maps a missing Apple proof to 422 APPLE_PROOF_REQUIRED', async () => {
      test.deleteOwnAccount.execute.mockRejectedValue(new AppleProofRequiredError());

      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/me/account-deletion',
        headers: AUTH,
      });

      expect(response.statusCode).toBe(422);
      expect(response.json().code).toBe('APPLE_PROOF_REQUIRED');
    });

    it('requires a session', async () => {
      const response = await test.app.inject({ method: 'POST', url: '/v1/me/account-deletion' });

      expect(response.statusCode).toBe(401);
      expect(test.deleteOwnAccount.execute).not.toHaveBeenCalled();
    });
  });

  describe('POST /v1/family/members/:memberId/account-deletion', () => {
    it('CA-16 deletes the Kids account through the authenticated administrator', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url: `/v1/family/members/${KIDS_ID}/account-deletion`,
        headers: AUTH,
      });

      expect(response.statusCode).toBe(204);
      expect(test.deleteKidsAccount.execute).toHaveBeenCalledWith(TEST_ACTOR, KIDS_ID);
    });

    it('CA-17 maps a refusal to 403 ACTION_NOT_ALLOWED', async () => {
      test.deleteKidsAccount.execute.mockRejectedValue(new ActionNotAllowedError());

      const response = await test.app.inject({
        method: 'POST',
        url: `/v1/family/members/${KIDS_ID}/account-deletion`,
        headers: AUTH,
      });

      expect(response.statusCode).toBe(403);
      expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
    });

    it('CA-18 maps a foreign target to 404 RESOURCE_NOT_FOUND', async () => {
      test.deleteKidsAccount.execute.mockRejectedValue(
        new NotFoundError('Family member not found.'),
      );

      const response = await test.app.inject({
        method: 'POST',
        url: `/v1/family/members/${KIDS_ID}/account-deletion`,
        headers: AUTH,
      });

      expect(response.statusCode).toBe(404);
      expect(response.json().code).toBe('RESOURCE_NOT_FOUND');
    });

    it('refuses a malformed member id and any body field', async () => {
      const malformed = await test.app.inject({
        method: 'POST',
        url: '/v1/family/members/not-a-uuid/account-deletion',
        headers: AUTH,
      });
      const withBody = await test.app.inject({
        method: 'POST',
        url: `/v1/family/members/${KIDS_ID}/account-deletion`,
        headers: AUTH,
        payload: { reason: 'x' },
      });

      expect(malformed.statusCode).toBe(400);
      expect(withBody.statusCode).toBe(400);
      expect(withBody.json().code).toBe('UNKNOWN_FIELD');
      expect(test.deleteKidsAccount.execute).not.toHaveBeenCalled();
    });
  });

  it('documents both protected operations in OpenAPI', async () => {
    const docs = await test.app.inject({ method: 'GET', url: '/docs/json' });
    expect(docs.statusCode).toBe(200);

    const own = docs.json().paths['/v1/me/account-deletion'].post;
    const kids = docs.json().paths['/v1/family/members/{memberId}/account-deletion'].post;

    expect(own.security).toEqual([{ bearerAuth: [] }]);
    expect(own.tags).toEqual(['Account']);
    expect(Object.keys(own.responses)).toEqual(expect.arrayContaining(['204', '401', '422']));
    expect(kids.security).toEqual([{ bearerAuth: [] }]);
    expect(Object.keys(kids.responses)).toEqual(expect.arrayContaining(['204', '403', '404']));
  });
});
