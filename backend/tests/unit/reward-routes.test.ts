import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  RewardPermissionError,
  RewardTitleAlreadyExistsError,
} from '../../src/modules/rewards/domain/reward-errors.js';
import { ValidationError } from '../../src/shared/domain/domain-error.js';
import { buildTestApp, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const ITEM = {
  id: '1a1b1c1d-2222-4333-8444-555566667777',
  title: 'Pizza',
  details: null,
  source: 'custom',
  createdAt: '2026-10-20T12:00:00.000Z',
};

describe('Reward HTTP contract — SPEC-015 phase 1 / SCRUM-80', () => {
  let test: TestApp;
  beforeEach(() => {
    test = buildTestApp();
    test.listRewardItems.execute.mockResolvedValue({ predefined: [], custom: [ITEM] });
    test.addRewardItem.execute.mockResolvedValue(ITEM);
  });
  afterEach(async () => test.app.close());

  it('CA-01/CA-06 lists only the use-case projection and rejects familyId in query', async () => {
    const ok = await test.app.inject({ method: 'GET', url: '/v1/reward-items', headers: AUTH });
    expect(ok.statusCode).toBe(200);
    expect(ok.json()).toEqual({ predefined: [], custom: [ITEM] });
    const rejected = await test.app.inject({
      method: 'GET',
      url: '/v1/reward-items?familyId=other',
      headers: AUTH,
    });
    expect(rejected.statusCode).toBe(400);
    expect(rejected.json().code).toBe('UNKNOWN_FIELD');
    const rejectedBody = await test.app.inject({
      method: 'GET',
      url: '/v1/reward-items',
      headers: { ...AUTH, 'content-type': 'application/json' },
      payload: { familyId: 'other' },
    });
    expect(rejectedBody.statusCode).toBe(400);
    expect(test.listRewardItems.execute).toHaveBeenCalledTimes(1);
  });

  it('CA-02 creates with 201 and refuses protected or unknown input', async () => {
    const ok = await test.app.inject({
      method: 'POST',
      url: '/v1/reward-items',
      headers: AUTH,
      payload: { title: 'Pizza' },
    });
    expect(ok.statusCode).toBe(201);
    expect(ok.json()).toEqual(ITEM);
    for (const field of ['familyId', 'source', 'createdAt', 'createdById']) {
      const rejected = await test.app.inject({
        method: 'POST',
        url: '/v1/reward-items',
        headers: AUTH,
        payload: { title: 'Pizza', [field]: 'forged' },
      });
      expect(rejected.statusCode).toBe(400);
      expect(rejected.json().code).toBe('UNKNOWN_FIELD');
    }
    expect(test.addRewardItem.execute).toHaveBeenCalledTimes(1);
  });

  it('CA-03/CA-04 returns Problem Details with stable field and duplicate codes', async () => {
    test.addRewardItem.execute
      .mockRejectedValueOnce(
        new ValidationError('Invalid title.', { title: ['REWARD_TITLE_REQUIRED'] }),
      )
      .mockRejectedValueOnce(new RewardTitleAlreadyExistsError());
    const invalid = await test.app.inject({
      method: 'POST',
      url: '/v1/reward-items',
      headers: AUTH,
      payload: { title: '' },
    });
    const duplicate = await test.app.inject({
      method: 'POST',
      url: '/v1/reward-items',
      headers: AUTH,
      payload: { title: 'Pizza' },
    });
    expect(invalid.statusCode).toBe(422);
    expect(invalid.headers['content-type']).toContain('application/problem+json');
    expect(invalid.json()).toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { title: ['REWARD_TITLE_REQUIRED'] },
    });
    expect(duplicate.statusCode).toBe(422);
    expect(duplicate.json().code).toBe('REWARD_TITLE_ALREADY_EXISTS');
  });

  it('CA-05 requires a session and maps denied access to 403', async () => {
    const absent = await test.app.inject({ method: 'GET', url: '/v1/reward-items' });
    expect(absent.statusCode).toBe(401);
    test.listRewardItems.execute.mockRejectedValue(new RewardPermissionError());
    const denied = await test.app.inject({ method: 'GET', url: '/v1/reward-items', headers: AUTH });
    expect(denied.statusCode).toBe(403);
    expect(denied.json().code).toBe('INSUFFICIENT_PERMISSIONS');
  });

  it('documents both secured routes and responses in /docs/json', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    expect(response.statusCode).toBe(200);
    const route = response.json().paths['/v1/reward-items'];
    for (const method of ['get', 'post']) {
      expect(route[method].tags).toContain('Rewards');
      expect(route[method].security).toEqual([{ bearerAuth: [] }]);
      expect(route[method].responses['401']).toBeDefined();
      expect(route[method].responses['403']).toBeDefined();
    }
    expect(route.get.responses['200']).toBeDefined();
    expect(route.post.responses['201']).toBeDefined();
    expect(route.post.responses['422']).toBeDefined();
  });
});
