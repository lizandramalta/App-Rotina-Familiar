import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  MissionCompletedProtectedError,
  SignalResolutionRequiredError,
  TaskAlreadyCompletedError,
  TaskManagementNotAllowedError,
} from '../../src/modules/tasks/domain/task-errors.js';
import { MissionReopenRequiresConfirmationError } from '../../src/modules/tasks/domain/task-reopening-errors.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access-token' };
const TASK_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const TASK = {
  id: TASK_ID,
  title: 'Arrumar os brinquedos',
  weight: 2,
  scheduledDate: '2026-10-10',
  assigneeIds: [TEST_ACTOR.memberId],
  note: 'Guardar no baú',
  status: 'pending',
  routineId: null,
  createdAt: '2026-10-08T12:00:00.000Z',
};

const OWN_TASKS = {
  items: [{ ...TASK, displayStatus: 'pending' }],
  nextCursor: null,
  familyCreatedAt: '2026-10-01',
};
const OWN_PROGRESS = { total: 1, completed: 0, percentage: 0, familyCreatedAt: '2026-10-01' };
const COMPLETION_RESULT = {
  task: { ...TASK, status: 'completed' },
  affectedResources: [
    { type: 'task', id: TASK_ID },
    { type: 'ownTasks', referenceDate: TASK.scheduledDate },
    { type: 'ownProgress', referenceDate: TASK.scheduledDate },
  ],
};
const REOPENING_RESULT = {
  task: TASK,
  affectedResources: {
    missionsReopened: [],
    participationsRemoved: 0,
    badgesRemoved: [],
    rewardRemoved: false,
  },
};

describe('Task routes — SPEC-007 phases 1 and 2', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.createTask.execute.mockResolvedValue(TASK);
    test.completeTask.execute.mockResolvedValue(COMPLETION_RESULT);
    test.reopenTask.execute.mockResolvedValue(REOPENING_RESULT);
    test.getTask.execute.mockResolvedValue(TASK);
    test.getOwnTasks.execute.mockResolvedValue(OWN_TASKS);
    test.getOwnProgress.execute.mockResolvedValue(OWN_PROGRESS);
    test.editTask.execute.mockResolvedValue(TASK);
    test.deleteTask.execute.mockResolvedValue({ id: TASK_ID });
  });

  afterEach(async () => test.app.close());

  it('SCRUM-56 / SPEC-011 CA-01 accepts a missing body and returns canonical effects', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/reopening`,
      headers: AUTH,
    });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual(REOPENING_RESULT);
    expect(test.reopenTask.execute).toHaveBeenCalledWith(
      TEST_ACTOR,
      TASK_ID,
      false,
      expect.any(String),
    );
  });

  it('SCRUM-56 / SPEC-011 CA-07 requires an active session', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/reopening`,
    });
    expect(response.statusCode).toBe(401);
    expect(test.reopenTask.execute).not.toHaveBeenCalled();
  });

  it('SCRUM-56 / SPEC-011 CA-02 returns confirmation details in problem+json', async () => {
    test.reopenTask.execute.mockRejectedValue(
      new MissionReopenRequiresConfirmationError([{ id: 'mission-id', title: 'Mission' }], false),
    );
    const response = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/reopening`,
      headers: AUTH,
      payload: {},
    });
    expect(response.statusCode).toBe(409);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.json()).toMatchObject({
      type: 'https://api.rotinafamiliar.app/problems/mission-reopen-requires-confirmation',
      title: 'Confirmação necessária',
      code: 'MISSION_REOPEN_REQUIRES_CONFIRMATION',
      missionsAffected: [{ id: 'mission-id', title: 'Mission' }],
      hasAcceptedReward: false,
    });
  });

  it('SCRUM-56 / SPEC-011 CA-03 accepts only confirm in the reopening body', async () => {
    const confirmed = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/reopening`,
      headers: AUTH,
      payload: { confirm: true },
    });
    expect(confirmed.statusCode).toBe(200);
    expect(test.reopenTask.execute).toHaveBeenCalledWith(
      TEST_ACTOR,
      TASK_ID,
      true,
      expect.any(String),
    );

    for (const payload of [{ confirm: 'yes' }, { confirm: true, familyId: TEST_ACTOR.familyId }]) {
      const invalid = await test.app.inject({
        method: 'POST',
        url: `/v1/tasks/${TASK_ID}/reopening`,
        headers: AUTH,
        payload,
      });
      expect(invalid.statusCode).toBe(400);
    }
    expect(test.reopenTask.execute).toHaveBeenCalledTimes(1);
  });

  it('SCRUM-56 / SPEC-011 CA-01 to CA-08 documents the secured route in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<
        string,
        {
          post?: {
            security?: unknown[];
            requestBody?: unknown;
            responses?: Record<string, unknown>;
          };
        }
      >;
    };
    const operation = document.paths['/v1/tasks/{taskId}/reopening']?.post;
    expect(operation?.security).toEqual([{ bearerAuth: [] }]);
    expect(operation?.requestBody).toBeDefined();
    for (const status of ['200', '400', '401', '403', '404', '409', '503']) {
      expect(operation?.responses).toHaveProperty(status);
    }
  });

  it('SCRUM-107 / SPEC-009 CA-01 and CA-11 returns canonical and displayed status for personal tasks', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/me/tasks?referenceDate=2026-10-10',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(OWN_TASKS);
    expect(test.getOwnTasks.execute).toHaveBeenCalledWith(TEST_ACTOR, '2026-10-10', undefined);
  });

  it('SCRUM-38 CA-01 returns the authenticated member daily progress', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/me/progress?referenceDate=2026-10-10',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual(OWN_PROGRESS);
    expect(test.getOwnProgress.execute).toHaveBeenCalledWith(TEST_ACTOR, '2026-10-10');
  });

  it('SCRUM-38 CA-01 rejects the family period field from personal routes', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: '/v1/me/tasks?referenceDate=2026-10-10&period=week',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: 'UNKNOWN_FIELD',
      fieldErrors: { period: ['UNKNOWN_FIELD'] },
    });
    expect(test.getOwnTasks.execute).not.toHaveBeenCalled();
  });

  it('SCRUM-107 / SPEC-009 CA-11 documents the personal status projection and security in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<
        string,
        {
          get: {
            security: unknown[];
            responses: Record<string, { content?: { 'application/json'?: { schema?: unknown } } }>;
          };
        }
      >;
    };

    expect(response.statusCode).toBe(200);
    expect(document.paths['/v1/me/tasks']?.get.security).toEqual([{ bearerAuth: [] }]);
    expect(document.paths['/v1/me/tasks']?.get.responses).toHaveProperty('422');
    const taskResponse = document.paths['/v1/me/tasks']?.get.responses['200']?.content?.[
      'application/json'
    ]?.schema as {
      required?: string[];
      properties?: { items?: { items?: { required?: string[]; properties?: object } } };
    };
    expect(taskResponse.properties?.items?.items?.required).toContain('displayStatus');
    expect(taskResponse.properties?.items?.items?.properties).toMatchObject({
      status: { enum: ['pending', 'awaitingConfirmation', 'completed'] },
      displayStatus: { enum: ['pending', 'awaitingConfirmation', 'completed'] },
    });
    // SPEC-009 E-05: the personal carousel's lower bound (RN49) so clients can disable
    // out-of-range days themselves instead of relying on a rejected query.
    expect(taskResponse.required).toContain('familyCreatedAt');
    expect(document.paths['/v1/me/progress']?.get.security).toEqual([{ bearerAuth: [] }]);
    expect(document.paths['/v1/me/progress']?.get.responses).toHaveProperty('503');
    const progressResponse = document.paths['/v1/me/progress']?.get.responses['200']?.content?.[
      'application/json'
    ]?.schema as { required?: string[] };
    expect(progressResponse.required).toContain('familyCreatedAt');
  });

  it('CA-01 creates a task as the authenticated adult and returns its canonical resource', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/tasks',
      headers: AUTH,
      payload: {
        title: TASK.title,
        weight: TASK.weight,
        scheduledDate: TASK.scheduledDate,
        assigneeIds: TASK.assigneeIds,
        note: TASK.note,
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.headers.location).toBe(`/v1/tasks/${TASK_ID}`);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(TASK);
    expect(test.createTask.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      title: TASK.title,
      weight: TASK.weight,
      scheduledDate: TASK.scheduledDate,
      assigneeIds: TASK.assigneeIds,
      note: TASK.note,
    });
  });

  it('CA-03 gets a task using only the actor from the active session', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/tasks/${TASK_ID}`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(test.getTask.execute).toHaveBeenCalledWith(TEST_ACTOR, TASK_ID);
  });

  it('SCRUM-40 completes a task without accepting actor or credit data from the client', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/completion`,
      headers: AUTH,
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual(COMPLETION_RESULT);
    expect(test.completeTask.execute).toHaveBeenCalledWith(TEST_ACTOR, TASK_ID);
  });

  it('SCRUM-40 rejects a completion body instead of trusting client actor or credit data', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/completion`,
      headers: AUTH,
      payload: { actorId: 'attacker', completedAt: '2026-10-10T00:00:00.000Z' },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: 'UNKNOWN_FIELD',
      fieldErrors: { actorId: ['UNKNOWN_FIELD'], completedAt: ['UNKNOWN_FIELD'] },
    });
    expect(test.completeTask.execute).not.toHaveBeenCalled();
  });

  it('SCRUM-40 maps permission and concurrent completion errors to the public contract', async () => {
    test.completeTask.execute.mockRejectedValueOnce(new TaskManagementNotAllowedError());
    const denied = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/completion`,
      headers: AUTH,
    });
    expect(denied.statusCode).toBe(403);
    expect(denied.json().code).toBe('ACTION_NOT_ALLOWED');

    test.completeTask.execute.mockRejectedValueOnce(
      new TaskAlreadyCompletedError('Task is already completed.'),
    );
    const conflict = await test.app.inject({
      method: 'POST',
      url: `/v1/tasks/${TASK_ID}/completion`,
      headers: AUTH,
    });
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json().code).toBe('TASK_ALREADY_COMPLETED');
  });

  it('documents the SCRUM-40 completion contract in OpenAPI', async () => {
    const response = await test.app.inject({ method: 'GET', url: '/docs/json' });
    const document = response.json() as {
      paths: Record<string, { post: { security: unknown[]; responses: Record<string, unknown> } }>;
    };

    const route = document.paths['/v1/tasks/{taskId}/completion']?.post;
    expect(route?.security).toEqual([{ bearerAuth: [] }]);
    expect(route?.responses).toHaveProperty('200');
    expect(route?.responses).toHaveProperty('409');
  });

  it.each(['familyId', 'status', 'createdAt', 'routineId'])(
    'rejects protected field %s with UNKNOWN_FIELD',
    async (field) => {
      const response = await test.app.inject({
        method: 'POST',
        url: '/v1/tasks',
        headers: AUTH,
        payload: {
          title: TASK.title,
          weight: 2,
          scheduledDate: TASK.scheduledDate,
          [field]: 'attacker-value',
        },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'UNKNOWN_FIELD',
        fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
      });
      expect(test.createTask.execute).not.toHaveBeenCalled();
    },
  );

  it('CA-12 through CA-14 forwards signal resolution to a PATCH', async () => {
    const response = await test.app.inject({
      method: 'PATCH',
      url: `/v1/tasks/${TASK_ID}`,
      headers: AUTH,
      payload: { note: 'Novo texto', signalResolution: 'keepAwaitingConfirmation' },
    });

    expect(response.statusCode).toBe(200);
    expect(test.editTask.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      taskId: TASK_ID,
      title: undefined,
      weight: undefined,
      scheduledDate: undefined,
      assigneeIds: undefined,
      note: 'Novo texto',
      signalResolution: 'keepAwaitingConfirmation',
    });
  });

  it('CA-02 maps management denial for Kids to ACTION_NOT_ALLOWED', async () => {
    test.createTask.execute.mockRejectedValue(new TaskManagementNotAllowedError());
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/tasks',
      headers: AUTH,
      payload: { title: TASK.title, weight: 2, scheduledDate: TASK.scheduledDate },
    });

    expect(response.statusCode).toBe(403);
    expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
  });

  it('maps phase-2 protection and signal errors to their specified contracts', async () => {
    test.editTask.execute.mockRejectedValueOnce(new SignalResolutionRequiredError());
    const unresolved = await test.app.inject({
      method: 'PATCH',
      url: `/v1/tasks/${TASK_ID}`,
      headers: AUTH,
      payload: { title: 'Novo título' },
    });
    expect(unresolved.statusCode).toBe(422);
    expect(unresolved.json().code).toBe('SIGNAL_RESOLUTION_REQUIRED');

    test.deleteTask.execute.mockRejectedValueOnce(new MissionCompletedProtectedError());
    const protectedTask = await test.app.inject({
      method: 'DELETE',
      url: `/v1/tasks/${TASK_ID}`,
      headers: AUTH,
    });
    expect(protectedTask.statusCode).toBe(409);
    expect(protectedTask.json().code).toBe('MISSION_COMPLETED_PROTECTED');
  });
});
