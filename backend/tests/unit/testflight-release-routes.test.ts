import { afterEach, describe, expect, it } from 'vitest';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const auth = { authorization: 'Bearer test-token' };

describe('TestFlight release scope — release-testflight CA-01/CA-02', () => {
  let test: TestApp | undefined;

  afterEach(async () => {
    await test?.app.close();
    test = undefined;
  });

  it('omits missions, rewards, Kids signals, badges and weekly reports from routes and OpenAPI', async () => {
    test = buildTestApp('testflight');
    const paths = [
      '/v1/missions',
      '/v1/reward-items',
      '/v1/tasks/11112222-3333-4444-5555-666677778888/signals',
      '/v1/kids/signals',
      '/v1/me/badges',
      '/v1/reports/weekly-snapshot',
    ];

    for (const path of paths) {
      const response = await test.app.inject({ method: 'GET', url: path, headers: auth });
      expect(response.statusCode, path).toBe(404);
    }

    const docs = await test.app.inject({ method: 'GET', url: '/docs/json' });
    expect(docs.statusCode).toBe(200);
    const openApiPaths = Object.keys(docs.json().paths);
    expect(
      openApiPaths.some((path) =>
        /missions|reward-items|kids\/signals|badges|reports\/weekly-snapshot|tasks\/\{taskId\}\/signals/.test(
          path,
        ),
      ),
    ).toBe(false);
    expect(openApiPaths).toContain('/v1/family/members');
    expect(openApiPaths).toContain('/v1/tasks');
    expect(
      docs.json().paths['/v1/families'].post.requestBody.content['application/json'].schema
        .properties.initialMembers.items.properties.role.enum,
    ).toEqual(['administrator', 'member']);
  });

  it('rejects Kids in initial family members before creating the family', async () => {
    test = buildTestApp('testflight');
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/families',
      headers: { 'x-installation-proof': 'installation-proof' },
      payload: {
        creationGrant: 'grant',
        creatorName: 'Maria',
        name: 'Casa',
        initialMembers: [{ name: 'Cris', role: 'kids' }],
      },
    });
    expect(response.statusCode).toBe(422);
    expect(response.json().fieldErrors).toEqual({
      'initialMembers[0].role': ['MEMBER_ROLE_INVALID'],
    });
    expect(test.createFamily.execute).not.toHaveBeenCalled();
  });

  it('rejects Kids creation and role changes before calling domain commands', async () => {
    test = buildTestApp('testflight');
    const creation = await test.app.inject({
      method: 'POST',
      url: '/v1/family/members',
      headers: auth,
      payload: { name: 'Cris', role: 'kids' },
    });
    expect(creation.statusCode).toBe(422);
    expect(creation.json().fieldErrors).toEqual({ role: ['MEMBER_ROLE_INVALID'] });
    expect(test.createMember.execute).not.toHaveBeenCalled();

    const roleChange = await test.app.inject({
      method: 'POST',
      url: '/v1/family/members/11112222-3333-4444-5555-666677778888/role-changes',
      headers: auth,
      payload: { role: 'kids' },
    });
    expect(roleChange.statusCode).toBe(422);
    expect(roleChange.json().fieldErrors).toEqual({ role: ['MEMBER_ROLE_INVALID'] });
  });

  it('blocks existing Kids sessions from protected resources', async () => {
    test = buildTestApp('testflight');
    test.authenticateSession.execute.mockResolvedValue({ ...TEST_ACTOR, role: 'kids' });

    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/me/profile',
      headers: auth,
    });
    expect(response.statusCode).toBe(403);
    expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
    expect(test.getOwnProfile.execute).not.toHaveBeenCalled();
  });
});
