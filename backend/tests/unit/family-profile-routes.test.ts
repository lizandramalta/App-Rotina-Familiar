/** SCRUM-106 / SPEC-002 CA-12: family GET/PATCH contract and OpenAPI security. */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const family = { id: TEST_ACTOR.familyId, name: 'Casa Silva', timeZoneId: 'America/Sao_Paulo' };
const auth = { authorization: 'Bearer token' };

describe('family profile routes', () => {
  let test: TestApp;
  beforeEach(() => {
    test = buildTestApp();
    test.getFamily.execute.mockResolvedValue(family);
    test.updateFamily.execute.mockResolvedValue({ ...family, name: 'Nova Casa' });
  });
  afterEach(async () => {
    await test.app.close();
  });

  it('GET /v1/family uses the session and returns the confirmed family', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/v1/family', headers: auth });
    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(family);
    expect(test.getFamily.execute).toHaveBeenCalledWith(TEST_ACTOR);
  });

  it('PATCH /v1/family accepts only name and never client family identity or time zone', async () => {
    const valid = await test.app.inject({
      method: 'PATCH',
      url: '/v1/family',
      headers: auth,
      payload: { name: 'Nova Casa' },
    });
    expect(valid.statusCode).toBe(200);
    expect(test.updateFamily.execute).toHaveBeenCalledWith(TEST_ACTOR, 'Nova Casa');
    for (const field of ['familyId', 'timeZoneId', 'role']) {
      const invalid = await test.app.inject({
        method: 'PATCH',
        url: '/v1/family',
        headers: auth,
        payload: { name: 'x', [field]: 'x' },
      });
      expect(invalid.statusCode).toBe(400);
      expect(invalid.json().code).toBe('UNKNOWN_FIELD');
    }
  });

  it('requires a session and documents both protected operations', async () => {
    const denied = await test.app.inject({ method: 'GET', url: '/v1/family' });
    expect(denied.statusCode).toBe(401);
    const docs = await test.app.inject({ method: 'GET', url: '/docs/json' });
    expect(docs.statusCode).toBe(200);
    const path = docs.json().paths['/v1/family'];
    expect(path.get.security).toEqual([{ bearerAuth: [] }]);
    expect(path.patch.security).toEqual([{ bearerAuth: [] }]);
    expect(path.patch.requestBody).toBeDefined();
  });
});
