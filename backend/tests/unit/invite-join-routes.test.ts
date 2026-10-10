/**
 * Contrato HTTP do ingresso por convite — SPEC-005 §5 (casos de uso dublados).
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  AccessSwitchConfirmationRequiredError,
  InvitePasswordInvalidError,
  InviteUnavailableError,
  JoinRecoveryUnavailableError,
  JoinResultUncertainError,
  PreviousSessionInvalidError,
  RateLimitedError,
} from '../../src/modules/access/domain/invite-errors.js';
import { buildTestApp, type TestApp } from '../support/build-test-app.js';

const ATTEMPT_ID = '5d1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const SESSION = {
  sessionId: 'session-1',
  memberId: 'member-1',
  familyId: 'family-1',
  role: 'kids',
  isFamilyCreator: false,
  accessToken: 'access-token',
  accessTokenExpiresAt: '2026-10-09T15:15:00.000Z',
  refreshToken: 'refresh-token',
};
const JOIN_BODY = {
  token: 'invite-token',
  password: 'K7M2QX',
  attemptId: ATTEMPT_ID,
  attemptSecret: 'attempt-secret-0123456789',
  installationProof: 'installation-proof',
  switchConfirmed: false,
};
const RECOVER_BODY = {
  attemptId: ATTEMPT_ID,
  attemptSecret: 'attempt-secret-0123456789',
  installationProof: 'installation-proof',
};

describe('Invite join routes — SPEC-005 phase 1', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
  });

  afterEach(async () => test.app.close());

  describe('POST /v1/access/invites/inspect', () => {
    const url = '/v1/access/invites/inspect';

    it('CA-01 answers 200 with only the status and no-store', async () => {
      test.inspectInvite.execute.mockResolvedValue({ status: 'available' });

      const response = await test.app.inject({ method: 'POST', url, payload: { token: 't' } });

      expect(response.statusCode).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual({ status: 'available' });
      expect(test.inspectInvite.execute).toHaveBeenCalledWith({
        token: 't',
        origin: expect.any(String),
        requestId: expect.any(String),
      });
    });

    it('CA-04 answers a neutral 404 problem', async () => {
      test.inspectInvite.execute.mockRejectedValue(new InviteUnavailableError());
      const response = await test.app.inject({ method: 'POST', url, payload: { token: 't' } });

      expect(response.statusCode).toBe(404);
      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json()).toMatchObject({ code: 'INVITE_UNAVAILABLE', status: 404 });
    });

    it('rejects unknown fields with UNKNOWN_FIELD and a missing token with VALIDATION_FAILED', async () => {
      const unknown = await test.app.inject({
        method: 'POST',
        url,
        payload: { token: 't', familyId: 'x' },
      });
      expect(unknown.statusCode).toBe(400);
      expect(unknown.json()).toMatchObject({ code: 'UNKNOWN_FIELD' });

      const missing = await test.app.inject({ method: 'POST', url, payload: {} });
      expect(missing.statusCode).toBe(400);
      expect(missing.json()).toMatchObject({ code: 'VALIDATION_FAILED' });
      expect(test.inspectInvite.execute).not.toHaveBeenCalled();
    });

    it('answers 429 with Retry-After', async () => {
      test.inspectInvite.execute.mockRejectedValue(new RateLimitedError(900));
      const response = await test.app.inject({ method: 'POST', url, payload: { token: 't' } });

      expect(response.statusCode).toBe(429);
      expect(response.headers['retry-after']).toBe('900');
      expect(response.json()).toMatchObject({ code: 'RATE_LIMITED' });
    });
  });

  describe('POST /v1/access/invite-joins', () => {
    const url = '/v1/access/invite-joins';

    it('CA-02 answers 201 with the SessionResult and no-store, without a previous session', async () => {
      test.joinFamilyByInvite.execute.mockResolvedValue(SESSION);

      const response = await test.app.inject({ method: 'POST', url, payload: JOIN_BODY });

      expect(response.statusCode).toBe(201);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual(SESSION);
      expect(test.joinFamilyByInvite.execute).toHaveBeenCalledWith(
        expect.objectContaining({ previousAccessToken: undefined, switchConfirmed: false }),
      );
    });

    it('forwards the optional Bearer as the previous session credential', async () => {
      test.joinFamilyByInvite.execute.mockResolvedValue(SESSION);

      await test.app.inject({
        method: 'POST',
        url,
        headers: { authorization: 'Bearer previous-token' },
        payload: { ...JOIN_BODY, switchConfirmed: true },
      });

      expect(test.joinFamilyByInvite.execute).toHaveBeenCalledWith(
        expect.objectContaining({ previousAccessToken: 'previous-token', switchConfirmed: true }),
      );
    });

    it('answers SESSION_INVALID for a malformed Authorization header', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url,
        headers: { authorization: 'Basic abc' },
        payload: JOIN_BODY,
      });

      expect(response.statusCode).toBe(401);
      expect(response.json()).toMatchObject({ code: 'SESSION_INVALID' });
      expect(test.joinFamilyByInvite.execute).not.toHaveBeenCalled();
    });

    it.each([
      ['familyId', 'attacker-family'],
      ['memberId', 'attacker-member'],
      ['role', 'administrator'],
      ['isFamilyCreator', true],
    ])('CA-02 rejects client supplied %s with UNKNOWN_FIELD', async (field, value) => {
      const response = await test.app.inject({
        method: 'POST',
        url,
        payload: { ...JOIN_BODY, [field]: value },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'UNKNOWN_FIELD' });
      expect(test.joinFamilyByInvite.execute).not.toHaveBeenCalled();
    });

    it.each([
      ['password', undefined],
      ['attemptId', 'not-a-uuid'],
      ['switchConfirmed', 'yes'],
      ['installationProof', ''],
    ])('rejects an invalid %s with VALIDATION_FAILED', async (field, value) => {
      const response = await test.app.inject({
        method: 'POST',
        url,
        payload: { ...JOIN_BODY, [field]: value },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'VALIDATION_FAILED' });
    });

    it.each([
      [new InviteUnavailableError(), 404, 'INVITE_UNAVAILABLE'],
      [new AccessSwitchConfirmationRequiredError(), 409, 'ACCESS_SWITCH_CONFIRMATION_REQUIRED'],
      [new InvitePasswordInvalidError(), 422, 'INVITE_PASSWORD_INVALID'],
      [new PreviousSessionInvalidError(), 401, 'SESSION_INVALID'],
      [new RateLimitedError(900), 429, 'RATE_LIMITED'],
      [new JoinResultUncertainError(), 503, 'JOIN_RESULT_UNCERTAIN'],
    ])('maps %s to %i %s as problem+json', async (error, status, code) => {
      test.joinFamilyByInvite.execute.mockRejectedValue(error);

      const response = await test.app.inject({ method: 'POST', url, payload: JOIN_BODY });

      expect(response.statusCode).toBe(status);
      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json()).toMatchObject({ code, status, requestId: expect.any(String) });
      // A resposta de erro nunca ecoa segredo da requisição.
      const raw = response.body;
      for (const secret of [JOIN_BODY.password, JOIN_BODY.attemptSecret, JOIN_BODY.token]) {
        expect(raw).not.toContain(secret);
      }
    });
  });

  describe('POST /v1/access/invite-joins/recover', () => {
    const url = '/v1/access/invite-joins/recover';

    it('CA-07 answers 200 with the same SessionResult and no-store', async () => {
      test.recoverInviteJoin.execute.mockResolvedValue(SESSION);

      const response = await test.app.inject({ method: 'POST', url, payload: RECOVER_BODY });

      expect(response.statusCode).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual(SESSION);
    });

    it('CA-08 answers a neutral 404 JOIN_RECOVERY_UNAVAILABLE', async () => {
      test.recoverInviteJoin.execute.mockRejectedValue(new JoinRecoveryUnavailableError());

      const response = await test.app.inject({ method: 'POST', url, payload: RECOVER_BODY });

      expect(response.statusCode).toBe(404);
      expect(response.json()).toMatchObject({ code: 'JOIN_RECOVERY_UNAVAILABLE' });
    });

    it('does not accept a password or invite token in the body', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url,
        payload: { ...RECOVER_BODY, password: 'K7M2QX' },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'UNKNOWN_FIELD' });
    });

    it('rejects a missing proof with VALIDATION_FAILED', async () => {
      const response = await test.app.inject({
        method: 'POST',
        url,
        payload: { attemptId: ATTEMPT_ID },
      });
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'VALIDATION_FAILED' });
    });
  });

  describe('OpenAPI document', () => {
    it('documents the three routes, their responses and the optional Bearer on the join', async () => {
      const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
      const spec = response.json() as {
        paths: Record<string, { post?: Record<string, unknown> }>;
      };

      const inspect = spec.paths['/v1/access/invites/inspect']?.post as
        { tags: string[]; responses: Record<string, unknown>; security?: unknown } | undefined;
      const joinRoute = spec.paths['/v1/access/invite-joins']?.post as
        { tags: string[]; responses: Record<string, unknown>; security?: unknown[] } | undefined;
      const recoverRoute = spec.paths['/v1/access/invite-joins/recover']?.post as
        { tags: string[]; responses: Record<string, unknown> } | undefined;

      expect(inspect?.tags).toEqual(['Access']);
      expect(Object.keys(inspect?.responses ?? {})).toEqual(
        expect.arrayContaining(['200', '400', '404', '429', '503']),
      );
      expect(inspect?.security).toBeUndefined();

      expect(joinRoute?.tags).toEqual(['Access']);
      expect(Object.keys(joinRoute?.responses ?? {})).toEqual(
        expect.arrayContaining(['201', '400', '401', '404', '409', '422', '429', '503']),
      );
      // Segurança opcional: sem Bearer a rota é pública sob posse do convite.
      expect(joinRoute?.security).toEqual([{}, { bearerAuth: [] }]);

      expect(recoverRoute?.tags).toEqual(['Access']);
      expect(Object.keys(recoverRoute?.responses ?? {})).toEqual(
        expect.arrayContaining(['200', '400', '404', '429', '503']),
      );
    });
  });
});
