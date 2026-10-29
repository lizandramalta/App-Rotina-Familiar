/** `GET /v1/me/profile`, `GET /v1/me/badges`, `GET /v1/me/badges/:awardId` (SPEC-006 Fase 1). */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const AWARD_ID = 'e5f6a7b8-0000-0000-0000-000000000001';

const OWN_PROFILE = {
  memberId: TEST_ACTOR.memberId,
  name: 'Maria Silva',
  familyName: 'Família Silva',
  nickname: 'Mari',
  photoMediaId: null,
  totalParticipations: 7,
  nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 3 },
};

const OWN_BADGES = {
  totalParticipations: 7,
  nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 3 },
  awards: [
    {
      awardId: AWARD_ID,
      tier: 'bronze',
      requiredMissionCount: 5,
      awardedAt: '2026-09-20T12:00:00.000Z',
    },
  ],
};

const BADGE_CONTRIBUTIONS = {
  awardId: AWARD_ID,
  tier: 'bronze',
  awardedAt: '2026-09-20T12:00:00.000Z',
  contributingMissions: [
    {
      missionId: 'f6a7b8c9-0000-0000-0000-000000000001',
      title: 'Organizar a sala',
      completedAt: '2026-09-18T20:00:00.000Z',
    },
  ],
};

describe('GET /v1/me/profile — SPEC-006', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.getOwnProfile.execute.mockResolvedValue(OWN_PROFILE);
  });
  afterEach(async () => test.app.close());

  it('CA-01 returns the authenticated member profile using only the session actor', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/v1/me/profile', headers: AUTH });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(OWN_PROFILE);
    expect(test.getOwnProfile.execute).toHaveBeenCalledWith(TEST_ACTOR);
  });

  it('documents the GetOwnProfile contract in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<string, { get: { security: unknown[]; responses: Record<string, unknown> } }>;
    };

    expect(response.statusCode).toBe(200);
    expect(document.paths['/v1/me/profile']?.get.security).toEqual([{ bearerAuth: [] }]);
    expect(document.paths['/v1/me/profile']?.get.responses).toHaveProperty('200');
  });
});

describe('GET /v1/me/badges — SPEC-006', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.getOwnBadges.execute.mockResolvedValue(OWN_BADGES);
  });
  afterEach(async () => test.app.close());

  it('CA-10/CA-11 returns totalParticipations, nextTier and the cumulative awards', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/v1/me/badges', headers: AUTH });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(OWN_BADGES);
    expect(test.getOwnBadges.execute).toHaveBeenCalledWith(TEST_ACTOR);
  });

  it('documents the GetOwnBadges contract in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<string, { get: { security: unknown[]; responses: Record<string, unknown> } }>;
    };

    expect(document.paths['/v1/me/badges']?.get.security).toEqual([{ bearerAuth: [] }]);
    expect(document.paths['/v1/me/badges']?.get.responses).toHaveProperty('200');
  });
});

describe('GET /v1/me/badges/{awardId} — SPEC-006', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.getBadgeContributions.execute.mockResolvedValue(BADGE_CONTRIBUTIONS);
  });
  afterEach(async () => test.app.close());

  it('CA-11 returns the award detail with the contributing missions', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/me/badges/${AWARD_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(BADGE_CONTRIBUTIONS);
    expect(test.getBadgeContributions.execute).toHaveBeenCalledWith(TEST_ACTOR, AWARD_ID);
  });

  it('CA-05 maps an award that is not the titular’s to 404 RESOURCE_NOT_FOUND', async () => {
    test.getBadgeContributions.execute.mockRejectedValueOnce(
      new NotFoundError('Badge award not found.'),
    );

    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/me/badges/${AWARD_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(404);
    expect(response.json().code).toBe('RESOURCE_NOT_FOUND');
  });

  it('documents the GetBadgeContributions contract in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<string, { get: { security: unknown[]; responses: Record<string, unknown> } }>;
    };

    const route = document.paths['/v1/me/badges/{awardId}']?.get;
    expect(route?.security).toEqual([{ bearerAuth: [] }]);
    expect(route?.responses).toHaveProperty('200');
    expect(route?.responses).toHaveProperty('404');
  });
});
