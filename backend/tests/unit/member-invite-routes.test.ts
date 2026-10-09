import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  NotFoundError,
} from '../../src/shared/domain/domain-error.js';
import { InviteNotIssuableError } from '../../src/modules/family/domain/family-errors.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const MEMBER_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const URL = `/v1/family/members/${MEMBER_ID}/invites`;
const CREDENTIALS = {
  inviteId: 'a1b2c3d4-e5f6-4890-abcd-ef1234567890',
  link: 'https://example.invalid/invite/opaque-token',
  password: 'K7M2QX',
};

describe('Member invite route — SPEC-004 phase 1', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.issueMemberInvite.execute.mockResolvedValue(CREDENTIALS);
  });

  afterEach(async () => test.app.close());

  it('CA-01/CA-05 answers 201 with transient credentials and no-store, using only the session actor', async () => {
    const response = await test.app.inject({ method: 'POST', url: URL, headers: AUTH });
    expect(response.statusCode).toBe(201);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(CREDENTIALS);
    expect(test.issueMemberInvite.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      memberId: MEMBER_ID,
      requestId: expect.any(String),
    });
  });

  it('requires authentication', async () => {
    test.authenticateSession.execute.mockRejectedValueOnce(
      Object.assign(new Error('x'), { statusCode: 401, code: 'ACCESS_TOKEN_INVALID' }),
    );
    const response = await test.app.inject({ method: 'POST', url: URL });
    expect(response.statusCode).toBe(401);
    expect(test.issueMemberInvite.execute).not.toHaveBeenCalled();
  });

  it.each(['familyId', 'role', 'isFamilyCreator', 'link', 'password', 'token'])(
    'rejects protected body field %s with UNKNOWN_FIELD',
    async (field) => {
      const response = await test.app.inject({
        method: 'POST',
        url: URL,
        headers: AUTH,
        payload: { [field]: 'attacker-value' },
      });
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'UNKNOWN_FIELD',
        fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
      });
      expect(test.issueMemberInvite.execute).not.toHaveBeenCalled();
    },
  );

  it('rejects a non-UUID memberId before reaching the use case', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/family/members/not-a-uuid/invites',
      headers: AUTH,
    });
    expect(response.statusCode).toBe(400);
    expect(test.issueMemberInvite.execute).not.toHaveBeenCalled();
  });

  it.each([
    ['ACTION_NOT_ALLOWED', 403, new ActionNotAllowedError()],
    ['RESOURCE_NOT_FOUND', 404, new NotFoundError('Family member not found.')],
    ['INVITE_NOT_ISSUABLE', 409, new InviteNotIssuableError()],
    ['DEPENDENCY_UNAVAILABLE', 503, new DependencyUnavailableError()],
  ])('maps %s to %i as problem+json', async (code, status, error) => {
    test.issueMemberInvite.execute.mockRejectedValue(error);
    const response = await test.app.inject({ method: 'POST', url: URL, headers: AUTH });
    expect(response.statusCode).toBe(status);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.json()).toMatchObject({ code, status, requestId: expect.any(String) });
  });
});
