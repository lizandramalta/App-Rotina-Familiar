import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  MissionCompletedProtectedError,
  MissionManagementNotAllowedError,
} from '../../src/modules/missions/domain/mission-errors.js';
import { buildTestApp, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const MISSION_ID = 'e4f5a6b7-c8d9-4123-8567-89abcdef0123';
const MISSION = {
  id: MISSION_ID,
  familyId: '11112222-3333-4444-5555-666677778888',
  title: 'Arrumar o quintal',
  note: null,
  status: 'inProgress',
  taskIds: ['9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e'],
  completedAt: null,
  isRedemptionAvailable: false,
  createdAt: '2026-10-19T12:00:00.000Z',
};

describe('Mission routes — SPEC-014 phase 1', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.createMission.execute.mockResolvedValue(MISSION);
    test.editMission.execute.mockResolvedValue(MISSION);
    test.getMissionDetail.execute.mockResolvedValue(MISSION);
    test.listMissions.execute.mockResolvedValue({ items: [], nextCursor: null });
    test.getMissionTaskOptions.execute.mockResolvedValue({ items: [], nextCursor: null });
  });

  afterEach(async () => test.app.close());

  it('CA-01 answers 201 with Location and the canonical resource', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/missions',
      headers: AUTH,
      payload: { title: 'Arrumar o quintal', taskIds: MISSION.taskIds },
    });

    expect(response.statusCode).toBe(201);
    expect(response.headers.location).toBe(`/v1/missions/${MISSION_ID}`);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(MISSION);
  });

  it.each(['status', 'completedAt', 'participations', 'reward'])(
    'rejects the protected field %s as UNKNOWN_FIELD',
    async (field) => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/missions',
        headers: AUTH,
        payload: { title: 'X', taskIds: MISSION.taskIds, [field]: 'x' },
      });

      expect(response.statusCode).toBe(400);
      expect(test.createMission.execute).not.toHaveBeenCalled();
    },
  );

  it('CA-02 maps a denied creation to 403 ACTION_NOT_ALLOWED', async () => {
    test.createMission.execute.mockRejectedValue(new MissionManagementNotAllowedError());

    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/missions',
      headers: AUTH,
      payload: { title: 'X', taskIds: MISSION.taskIds },
    });

    expect(response.statusCode).toBe(403);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.json()).toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
  });

  it('CA-10 maps a protected mission to 409 MISSION_COMPLETED_PROTECTED', async () => {
    test.editMission.execute.mockRejectedValue(new MissionCompletedProtectedError());

    const response = await test.app.inject({
      method: 'PATCH',
      url: `/v1/missions/${MISSION_ID}`,
      headers: AUTH,
      payload: { title: 'Novo' },
    });

    expect(response.statusCode).toBe(409);
    expect(response.json()).toMatchObject({ code: 'MISSION_COMPLETED_PROTECTED' });
  });

  it('serves the static task-options route before the :missionId route', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/missions/task-options?query=quintal',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(test.getMissionTaskOptions.execute).toHaveBeenCalledWith(
      expect.anything(),
      'quintal',
      undefined,
    );
    expect(test.getMissionDetail.execute).not.toHaveBeenCalled();
  });

  it('reads the list and the detail with no-store', async () => {
    const list = await test.app.inject({ method: 'GET', url: '/v1/missions', headers: AUTH });
    const detail = await test.app.inject({
      method: 'GET',
      url: `/v1/missions/${MISSION_ID}`,
      headers: AUTH,
    });

    expect(list.statusCode).toBe(200);
    expect(detail.statusCode).toBe(200);
    expect(detail.headers['cache-control']).toBe('no-store');
  });

  it('requires authentication on every mission route', async () => {
    for (const [method, url] of [
      ['POST', '/v1/missions'],
      ['GET', '/v1/missions'],
      ['GET', '/v1/missions/task-options'],
      ['GET', `/v1/missions/${MISSION_ID}`],
      ['PATCH', `/v1/missions/${MISSION_ID}`],
    ] as const) {
      const response = await test.app.inject({
        method,
        url,
        payload: method === 'GET' ? undefined : {},
      });
      expect(response.statusCode, `${method} ${url}`).toBe(401);
    }
  });

  it('documents the mission routes with bearer security in /docs/json', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const paths = response.json().paths as Record<string, Record<string, { security?: unknown }>>;

    for (const [path, method] of [
      ['/v1/missions', 'post'],
      ['/v1/missions', 'get'],
      ['/v1/missions/task-options', 'get'],
      ['/v1/missions/{missionId}', 'get'],
      ['/v1/missions/{missionId}', 'patch'],
    ] as const) {
      expect(paths[path]?.[method]?.security, `${method} ${path}`).toEqual([{ bearerAuth: [] }]);
    }
  });
});
