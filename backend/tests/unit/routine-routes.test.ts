import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  ActionNotAllowedError,
  NotFoundError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const ROUTINE_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const ROUTINE = {
  id: ROUTINE_ID,
  title: 'Separar recicláveis',
  weight: 2,
  assigneeIds: [TEST_ACTOR.memberId],
  note: 'Lavar as embalagens antes',
  startDate: '2026-10-10',
  frequencyDays: 7,
  isActive: true,
  materializationState: 'complete',
};

describe('Routine routes — SPEC-008 phase 1', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.createRoutine.execute.mockResolvedValue(ROUTINE);
    test.getRoutine.execute.mockResolvedValue(ROUTINE);
  });

  afterEach(async () => test.app.close());

  it('CA-01 creates a routine and returns its canonical configuration', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/routines',
      headers: AUTH,
      payload: {
        title: ROUTINE.title,
        weight: ROUTINE.weight,
        assigneeIds: ROUTINE.assigneeIds,
        note: ROUTINE.note,
        startDate: ROUTINE.startDate,
        frequencyDays: ROUTINE.frequencyDays,
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.headers.location).toBe(`/v1/routines/${ROUTINE_ID}`);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(ROUTINE);
    expect(test.createRoutine.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      title: ROUTINE.title,
      weight: ROUTINE.weight,
      assigneeIds: ROUTINE.assigneeIds,
      note: ROUTINE.note,
      startDate: ROUTINE.startDate,
      frequencyDays: ROUTINE.frequencyDays,
    });
  });

  it('rejects an unknown field on creation with UNKNOWN_FIELD, without calling the use case', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/routines',
      headers: AUTH,
      payload: {
        title: ROUTINE.title,
        weight: ROUTINE.weight,
        startDate: ROUTINE.startDate,
        frequencyDays: ROUTINE.frequencyDays,
        endDate: '2026-12-31',
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: 'UNKNOWN_FIELD',
      fieldErrors: { endDate: ['UNKNOWN_FIELD'] },
    });
    expect(test.createRoutine.execute).not.toHaveBeenCalled();
  });

  it('CA-02 maps a validation failure to 422 VALIDATION_FAILED with the stable field code', async () => {
    test.createRoutine.execute.mockRejectedValue(
      new ValidationError('Frequency must be 1, 7, 14, 21 or 28 days.', {
        frequencyDays: ['FREQUENCY_DAYS_INVALID'],
      }),
    );

    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/routines',
      headers: AUTH,
      payload: {
        title: ROUTINE.title,
        weight: ROUTINE.weight,
        startDate: ROUTINE.startDate,
        frequencyDays: 3,
      },
    });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { frequencyDays: ['FREQUENCY_DAYS_INVALID'] },
    });
  });

  it('CA-03 maps Kids denial to 403 ACTION_NOT_ALLOWED', async () => {
    test.createRoutine.execute.mockRejectedValue(new ActionNotAllowedError());

    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/routines',
      headers: AUTH,
      payload: {
        title: ROUTINE.title,
        weight: ROUTINE.weight,
        startDate: ROUTINE.startDate,
        frequencyDays: ROUTINE.frequencyDays,
      },
    });

    expect(response.statusCode).toBe(403);
    expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
  });

  it('gets a routine using only the actor from the active session', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/routines/${ROUTINE_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(ROUTINE);
    expect(test.getRoutine.execute).toHaveBeenCalledWith(TEST_ACTOR, ROUTINE_ID);
  });

  it('CA-04 maps an isolated/nonexistent routine to 404 RESOURCE_NOT_FOUND', async () => {
    test.getRoutine.execute.mockRejectedValue(new NotFoundError('Routine not found.'));

    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/routines/${ROUTINE_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(404);
    expect(response.json().code).toBe('RESOURCE_NOT_FOUND');
  });

  it('CA-03 maps Kids denial on GET to 403 ACTION_NOT_ALLOWED', async () => {
    test.getRoutine.execute.mockRejectedValue(new ActionNotAllowedError());

    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/routines/${ROUTINE_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(403);
    expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
  });

  it('documents the routine contracts in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<
        string,
        {
          post?: { security: unknown[]; responses: Record<string, unknown> };
          get?: { security: unknown[]; responses: Record<string, unknown> };
        }
      >;
    };

    expect(response.statusCode).toBe(200);
    const createRoute = document.paths['/v1/routines']?.post;
    expect(createRoute?.security).toEqual([{ bearerAuth: [] }]);
    expect(createRoute?.responses).toHaveProperty('201');
    expect(createRoute?.responses).toHaveProperty('422');

    const getRoute = document.paths['/v1/routines/{routineId}']?.get;
    expect(getRoute?.security).toEqual([{ bearerAuth: [] }]);
    expect(getRoute?.responses).toHaveProperty('200');
    expect(getRoute?.responses).toHaveProperty('404');
  });

  it('SPEC-008 CA-07 sends only allowed fields to the future update and returns affected IDs', async () => {
    const result = { routine: ROUTINE, updatedTaskIds: [ROUTINE_ID], preservedTaskIds: [] };
    test.updateFutureRoutine.execute.mockResolvedValue(result);
    const response = await test.app.inject({
      method: 'PATCH',
      url: `/v1/routines/${ROUTINE_ID}`,
      headers: AUTH,
      payload: { fromTaskId: ROUTINE_ID, title: 'Novo título', assigneeIds: [] },
    });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual(result);
    expect(test.updateFutureRoutine.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      routineId: ROUTINE_ID,
      fromTaskId: ROUTINE_ID,
      title: 'Novo título',
      weight: undefined,
      assigneeIds: [],
      note: undefined,
    });
  });

  it.each(['startDate', 'frequencyDays', 'signalResolution', 'scheduledDate'])(
    'SPEC-008 CA-07 rejects protected PATCH field %s before the use case',
    async (field) => {
      const response = await test.app.inject({
        method: 'PATCH',
        url: `/v1/routines/${ROUTINE_ID}`,
        headers: AUTH,
        payload: { fromTaskId: ROUTINE_ID, [field]: 'invalid' },
      });
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'UNKNOWN_FIELD',
        fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
      });
      expect(test.updateFutureRoutine.execute).not.toHaveBeenCalled();
    },
  );

  it('SPEC-008 CA-08 returns the closure scope and rejects unknown fields', async () => {
    const result = {
      routineId: ROUTINE_ID,
      deletedTaskIds: [ROUTINE_ID],
      preservedTaskIds: [],
      generationEnded: true,
    };
    test.deleteFutureRoutineTasks.execute.mockResolvedValue(result);
    const success = await test.app.inject({
      method: 'POST',
      url: `/v1/routines/${ROUTINE_ID}/future-task-deletions`,
      headers: AUTH,
      payload: { fromTaskId: ROUTINE_ID },
    });
    expect(success.statusCode).toBe(200);
    expect(success.json()).toEqual(result);
    const rejected = await test.app.inject({
      method: 'POST',
      url: `/v1/routines/${ROUTINE_ID}/future-task-deletions`,
      headers: AUTH,
      payload: { fromTaskId: ROUTINE_ID, familyId: TEST_ACTOR.familyId },
    });
    expect(rejected.statusCode).toBe(400);
    expect(rejected.json().code).toBe('UNKNOWN_FIELD');
    expect(test.deleteFutureRoutineTasks.execute).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['PATCH', `/v1/routines/${ROUTINE_ID}`],
    ['POST', `/v1/routines/${ROUTINE_ID}/future-task-deletions`],
  ] as const)('requires an active session for %s %s', async (method, url) => {
    const response = await test.app.inject({
      method,
      url,
      payload: { fromTaskId: ROUTINE_ID },
    });
    expect(response.statusCode).toBe(401);
    expect(test.updateFutureRoutine.execute).not.toHaveBeenCalled();
    expect(test.deleteFutureRoutineTasks.execute).not.toHaveBeenCalled();
  });

  it('documents both SPEC-008 phase 2 routes with bearer security and error responses', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const paths = response.json().paths as Record<
      string,
      Record<
        string,
        {
          security: unknown[];
          tags: string[];
          requestBody: { content: Record<string, { schema: { additionalProperties: boolean } }> };
          responses: Record<string, unknown>;
        }
      >
    >;
    for (const [path, method] of [
      ['/v1/routines/{routineId}', 'patch'],
      ['/v1/routines/{routineId}/future-task-deletions', 'post'],
    ]) {
      const route = paths[path]?.[method];
      expect(route?.security).toEqual([{ bearerAuth: [] }]);
      expect(route?.tags).toContain('Routines');
      expect(route?.requestBody.content['application/json']?.schema.additionalProperties).toBe(
        false,
      );
      for (const status of ['200', '400', '401', '403', '404', '409', '422', '503']) {
        expect(route?.responses).toHaveProperty(status);
      }
    }
  });
});
