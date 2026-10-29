/**
 * Autenticação Bearer das rotas protegidas de `/v1/media` e `/v1/me/profile`
 * (SPEC-002 §5.2: "as rotas usam Bearer da sessão recém-criada").
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { AccessTokenInvalidError } from '../../src/modules/access/domain/access-errors.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const PROFILE_BODY = { photoMediaId: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e' };

describe('Bearer authentication on protected routes', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.updateOwnProfile.execute.mockResolvedValue({
      memberId: TEST_ACTOR.memberId,
      name: 'Maria Silva',
      familyName: 'Família Silva',
      nickname: null,
      photoMediaId: PROFILE_BODY.photoMediaId,
      totalParticipations: 0,
      nextTier: { code: 'bronze', requiredMissionCount: 5, remaining: 5 },
    });
  });

  afterEach(async () => {
    await test.app.close();
  });

  const patch = (headers: Record<string, string>, payload: object = PROFILE_BODY) =>
    test.app.inject({ method: 'PATCH', url: '/v1/me/profile', headers, payload });

  it('resolves the actor from the Bearer token', async () => {
    const response = await patch({ authorization: 'Bearer opaque-access-token' });

    expect(response.statusCode).toBe(200);
    expect(test.authenticateSession.execute).toHaveBeenCalledWith('opaque-access-token');
    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      nickname: undefined,
      photoMediaId: PROFILE_BODY.photoMediaId,
    });
  });

  it('accepts the Bearer scheme case-insensitively', async () => {
    const response = await patch({ authorization: 'bearer opaque-access-token' });

    expect(response.statusCode).toBe(200);
  });

  it.each([
    ['no Authorization header', {}],
    ['a non-Bearer scheme', { authorization: 'Basic dXNlcjpwYXNz' }],
    ['an empty token', { authorization: 'Bearer ' }],
  ])('rejects %s with 401 ACCESS_TOKEN_INVALID', async (_label, headers) => {
    const response = await patch(headers);

    expect(response.statusCode).toBe(401);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.json().code).toBe('ACCESS_TOKEN_INVALID');
    expect(test.updateOwnProfile.execute).not.toHaveBeenCalled();
  });

  it('rejects an expired or revoked token with 401', async () => {
    test.authenticateSession.execute.mockRejectedValue(new AccessTokenInvalidError());

    const response = await patch({ authorization: 'Bearer expired-token' });

    expect(response.statusCode).toBe(401);
    expect(test.updateOwnProfile.execute).not.toHaveBeenCalled();
  });

  it('authenticates before validating the body: a bad body without a session is 401, not 400', async () => {
    const response = await patch({}, { unexpected: true });

    expect(response.statusCode).toBe(401);
  });

  it('protects POST /v1/media too', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/media',
      headers: { 'content-type': 'multipart/form-data; boundary=x' },
      payload: '--x--',
    });

    expect(response.statusCode).toBe(401);
    expect(test.uploadMedia.execute).not.toHaveBeenCalled();
  });
});
