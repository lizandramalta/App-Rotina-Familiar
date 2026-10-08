import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  MissionCompletedProtectedError,
  SignalResolutionRequiredError,
  TaskManagementNotAllowedError,
} from '../../src/modules/tasks/domain/task-errors.js';
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

describe('Task routes — SPEC-007 phases 1 and 2', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.createTask.execute.mockResolvedValue(TASK);
    test.getTask.execute.mockResolvedValue(TASK);
    test.editTask.execute.mockResolvedValue(TASK);
    test.deleteTask.execute.mockResolvedValue({ id: TASK_ID });
  });

  afterEach(async () => test.app.close());

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
