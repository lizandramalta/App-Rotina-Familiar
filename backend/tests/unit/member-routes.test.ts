import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const MEMBER = {
  id: '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e',
  name: 'Marina Silva',
  role: 'member',
  isFamilyCreator: false,
  createdAt: '2026-10-08T12:00:00.000Z',
};

describe('Member routes — SPEC-003 phase 1', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.listFamilyMembers.execute.mockResolvedValue({
      items: [MEMBER],
      nextCursor: 'opaque-next',
    });
    test.getMemberDetail.execute.mockResolvedValue({
      ...MEMBER,
      capabilities: { manageMembers: true },
    });
    test.createMember.execute.mockResolvedValue(MEMBER);
  });

  afterEach(async () => test.app.close());

  it('CA-03 lists members using only the authenticated actor and forwards the cursor', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/family/members?cursor=opaque-current',
      headers: AUTH,
    });
    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual({ items: [MEMBER], nextCursor: 'opaque-next' });
    expect(test.listFamilyMembers.execute).toHaveBeenCalledWith(TEST_ACTOR, 'opaque-current');
  });

  it('returns the scoped detail and its confirmed actor capability', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/family/members/${MEMBER.id}`,
      headers: AUTH,
    });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({ id: MEMBER.id, capabilities: { manageMembers: true } });
  });

  it('CA-01 creates without a session or invitation and returns its canonical projection', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/family/members',
      headers: AUTH,
      payload: { name: MEMBER.name, role: MEMBER.role },
    });
    expect(response.statusCode).toBe(201);
    expect(response.headers.location).toBe(`/v1/family/members/${MEMBER.id}`);
    expect(response.json()).toEqual(MEMBER);
    expect(test.createMember.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      name: MEMBER.name,
      role: MEMBER.role,
    });
  });

  it.each(['familyId', 'isFamilyCreator', 'nickname', 'photoMediaId'])(
    'rejects protected field %s with UNKNOWN_FIELD',
    async (field) => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/family/members',
        headers: AUTH,
        payload: { name: MEMBER.name, role: MEMBER.role, [field]: 'attacker-value' },
      });
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'UNKNOWN_FIELD',
        fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
      });
      expect(test.createMember.execute).not.toHaveBeenCalled();
    },
  );

  it('maps a scoped-out detail to RESOURCE_NOT_FOUND', async () => {
    test.getMemberDetail.execute.mockRejectedValue(new NotFoundError('Family member not found.'));
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/family/members/${MEMBER.id}`,
      headers: AUTH,
    });
    expect(response.statusCode).toBe(404);
    expect(response.json().code).toBe('RESOURCE_NOT_FOUND');
  });

  it('documents the member routes, Bearer security and result schemas in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const spec = response.json() as {
      paths: Record<
        string,
        {
          get?: { security?: unknown };
          post?: { responses: Record<string, unknown> };
          patch?: { summary?: string; security?: unknown; responses: Record<string, unknown> };
        }
      >;
    };
    expect(spec.paths['/v1/family/members']?.get?.security).toEqual([{ bearerAuth: [] }]);
    expect(spec.paths['/v1/family/members']?.post?.responses).toMatchObject({
      201: expect.anything(),
      400: expect.anything(),
      422: expect.anything(),
      503: expect.anything(),
    });
    expect(spec.paths['/v1/family/members/{memberId}']?.get?.security).toEqual([
      { bearerAuth: [] },
    ]);
    expect(spec.paths['/v1/family/members/{memberId}']?.patch).toMatchObject({
      summary: 'Correct a Kids member administrative name as a family administrator',
      security: [{ bearerAuth: [] }],
      responses: { 200: expect.anything(), 403: expect.anything(), 404: expect.anything() },
    });
  });
});
