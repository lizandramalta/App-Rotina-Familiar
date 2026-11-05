import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';
import { DependencyUnavailableError, NotFoundError } from '../../src/shared/domain/domain-error.js';
import { AccessTokenInvalidError } from '../../src/modules/access/domain/access-errors.js';

const id = '11111111-2222-4333-8444-555555555555';
const base = '/v1/me/weekly-recognitions';
const headers = { authorization: 'Bearer test-token' };
const view = {
  id,
  period: {
    startsAt: '2026-10-19T03:00:00.000Z',
    endsAt: '2026-10-26T03:00:00.000Z',
    referenceWeek: '2026-10-19',
  },
  timeZoneId: 'America/Sao_Paulo',
  isTransition: false,
  points: 6,
  completedTasks: 2,
  isTie: true,
  processedAt: '2026-10-26T03:00:01.000Z',
  openedAt: null,
};

describe('SPEC-020 CA-05/06 — recognition HTTP and OpenAPI', () => {
  let context: TestApp;
  beforeEach(() => {
    context = buildTestApp();
  });
  afterEach(() => context.app.close());

  it('lists and opens an owned result without serializing private fields', async () => {
    context.recognitions.list.mockResolvedValue({ items: [{ ...view, memberId: 'private' }] });
    const list = await context.app.inject({ url: base, headers });
    expect(list.statusCode).toBe(200);
    expect(list.json()).toEqual({ items: [view] });
    expect(list.headers['cache-control']).toBe('no-store');
    expect(context.recognitions.list).toHaveBeenCalledWith(TEST_ACTOR);
    context.recognitions.open.mockResolvedValue({ ...view, openedAt: view.processedAt });
    const opening = await context.app.inject({
      method: 'POST',
      url: `${base}/${id}/opening`,
      headers,
      payload: {},
    });
    expect(opening.statusCode).toBe(200);
    expect(opening.json().openedAt).toBe(view.processedAt);
    expect(context.recognitions.open).toHaveBeenCalledWith(TEST_ACTOR, id);
    expect(
      (await context.app.inject({ method: 'POST', url: `${base}/${id}/opening`, headers }))
        .statusCode,
    ).toBe(200);
    context.recognitions.get.mockResolvedValue(view);
    expect((await context.app.inject({ url: `${base}/${id}`, headers })).json()).toEqual(view);
  });

  it('rejects missing or revoked sessions with the SPEC-020 error', async () => {
    const missing = await context.app.inject({ url: base });
    expect(missing.statusCode).toBe(401);
    expect(missing.json().code).toBe('SESSION_EXPIRED');
    context.authenticateSession.execute.mockRejectedValue(new AccessTokenInvalidError());
    expect((await context.app.inject({ url: base, headers })).json().code).toBe('SESSION_EXPIRED');
    expect(context.recognitions.list).not.toHaveBeenCalled();
  });

  it('validates identifiers and preserves absent, out-of-scope and dependency errors', async () => {
    expect((await context.app.inject({ url: `${base}/bad-id`, headers })).statusCode).toBe(400);
    context.recognitions.get.mockRejectedValue(new NotFoundError('Recognition not found.'));
    expect((await context.app.inject({ url: `${base}/${id}`, headers })).json().code).toBe(
      'RESOURCE_NOT_FOUND',
    );
    context.recognitions.open.mockRejectedValue(new NotFoundError('Recognition not found.'));
    expect(
      (
        await context.app.inject({
          method: 'POST',
          url: `${base}/${id}/opening`,
          headers,
          payload: {},
        })
      ).statusCode,
    ).toBe(404);
    context.recognitions.list.mockRejectedValue(new DependencyUnavailableError());
    expect((await context.app.inject({ url: base, headers })).statusCode).toBe(503);
  });

  it('returns 503 when session verification cannot reach persistence', async () => {
    context.authenticateSession.execute.mockRejectedValue(new Error('database unavailable'));
    const response = await context.app.inject({ url: base, headers });
    expect(response.statusCode).toBe(503);
    expect(response.json().code).toBe('DEPENDENCY_UNAVAILABLE');
    expect(context.recognitions.list).not.toHaveBeenCalled();
  });

  it('documents all routes, bearer protection, request and response schemas in /docs/json', async () => {
    const response = await context.app.inject({ url: '/docs/json' });
    expect(response.statusCode).toBe(200);
    const paths = response.json().paths;
    for (const [path, method] of [
      [base, 'get'],
      [`${base}/{recognitionId}`, 'get'],
      [`${base}/{recognitionId}/opening`, 'post'],
    ]) {
      const operation = paths[path!][method!];
      expect(operation.security).toEqual([{ bearerAuth: [] }]);
      expect(operation.tags).toContain('Recognition');
      for (const code of ['200', '400', '401', '404', '503'])
        expect(operation.responses[code]).toBeDefined();
    }
    expect(paths[`${base}/{recognitionId}`].get.parameters[0].schema.format).toBe('uuid');
  });
});
