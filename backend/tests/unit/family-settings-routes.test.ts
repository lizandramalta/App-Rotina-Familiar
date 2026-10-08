/**
 * Rotas de fuso na borda HTTP (SPEC-002 Fase 3): CA-05, CA-06/CA-07 (contrato) e
 * CA-04-style `UNKNOWN_FIELD`. Os casos de uso são dublês; a regra está em
 * family-settings.test.ts.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { AccessTokenInvalidError } from '../../src/modules/access/domain/access-errors.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const AUTH = { authorization: 'Bearer opaque-access' };

const SETTINGS = {
  timeZoneId: 'America/Sao_Paulo',
  scheduledTimeZoneChange: { timeZoneId: 'Asia/Tokyo', effectiveAt: '2026-10-12T03:00:00.000Z' },
  limits: {
    startsAt: '2026-10-07T15:00:00.000Z',
    endsAt: '2026-10-12T03:00:00.000Z',
    timeZoneId: 'America/Sao_Paulo',
    isTransition: false,
  },
};

const PREVIEW = {
  proposedTimeZoneId: 'Asia/Tokyo',
  application: 'immediate',
  effectiveAt: '2026-10-08T15:00:00.000Z',
  isTransition: true,
  effectiveLimits: {
    startsAt: '2026-10-07T15:00:00.000Z',
    endsAt: '2026-10-11T15:00:00.000Z',
    timeZoneId: 'Asia/Tokyo',
    isTransition: true,
  },
};

const BODY = { timeZoneId: 'Asia/Tokyo', application: 'immediate' };

describe('family settings routes', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.getFamilySettings.execute.mockResolvedValue(SETTINGS);
    test.previewTimeZoneChange.execute.mockResolvedValue(PREVIEW);
    test.changeTimeZone.execute.mockResolvedValue({ ...SETTINGS, scheduledTimeZoneChange: null });
  });

  afterEach(async () => {
    await test.app.close();
  });

  const routes = [
    { method: 'GET', url: '/v1/family/settings', mock: () => test.getFamilySettings },
    {
      method: 'POST',
      url: '/v1/family/time-zone-changes/preview',
      mock: () => test.previewTimeZoneChange,
    },
    { method: 'POST', url: '/v1/family/time-zone-changes', mock: () => test.changeTimeZone },
  ] as const;

  const call = (
    route: (typeof routes)[number],
    headers: Record<string, string> = AUTH,
    body = BODY,
  ) =>
    test.app.inject({
      method: route.method,
      url: route.url,
      headers,
      ...(route.method === 'POST' ? { payload: body } : {}),
    });

  describe('authentication', () => {
    it.each(routes)('$method $url requires a session (401)', async (route) => {
      test.authenticateSession.execute.mockRejectedValue(new AccessTokenInvalidError());

      const response = await call(route, {});

      expect(response.statusCode).toBe(401);
      expect(route.mock().execute).not.toHaveBeenCalled();
    });

    it.each(routes)('$method $url derives the actor from the session only', async (route) => {
      await call(route);

      const command = route.mock().execute.mock.calls[0]?.[0];
      expect(command.actor).toEqual(TEST_ACTOR);
      expect(command).not.toHaveProperty('familyId');
    });
  });

  describe('CA-05: non-administrators', () => {
    it.each(routes)('$method $url maps ACTION_NOT_ALLOWED to 403 problem+json', async (route) => {
      route.mock().execute.mockRejectedValue(new ActionNotAllowedError());

      const response = await call(route);

      expect(response.statusCode).toBe(403);
      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json()).toMatchObject({ status: 403, code: 'ACTION_NOT_ALLOWED' });
      expect(response.json().requestId).toEqual(expect.any(String));
    });
  });

  describe('success contracts', () => {
    it('GET /family/settings answers 200, no-store and the settings', async () => {
      const response = await call(routes[0]);

      expect(response.statusCode).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual(SETTINGS);
    });

    it('GET /family/settings serializes a null scheduled change', async () => {
      test.getFamilySettings.execute.mockResolvedValue({
        ...SETTINGS,
        scheduledTimeZoneChange: null,
      });

      const response = await call(routes[0]);

      expect(response.json().scheduledTimeZoneChange).toBeNull();
    });

    it('preview answers 200 with the effective limits', async () => {
      const response = await call(routes[1]);

      expect(response.statusCode).toBe(200);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual(PREVIEW);
      expect(test.previewTimeZoneChange.execute.mock.calls[0]?.[0]).toMatchObject(BODY);
    });

    it('confirmation answers 200 with the confirmed settings', async () => {
      const response = await call(routes[2]);

      expect(response.statusCode).toBe(200);
      expect(response.json()).toMatchObject({ timeZoneId: 'America/Sao_Paulo' });
      expect(test.changeTimeZone.execute.mock.calls[0]?.[0]).toMatchObject(BODY);
    });
  });

  describe('protected fields are rejected, not ignored', () => {
    it.each(['familyId', 'memberId', 'role', 'isFamilyCreator', 'scheduledTimeZoneChange'])(
      'rejects %s with 400 UNKNOWN_FIELD on preview and confirmation',
      async (field) => {
        for (const route of [routes[1], routes[2]]) {
          const response = await call(route, AUTH, { ...BODY, [field]: 'attacker-controlled' });

          expect(response.statusCode).toBe(400);
          expect(response.json()).toMatchObject({
            code: 'UNKNOWN_FIELD',
            fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
          });
          expect(route.mock().execute).not.toHaveBeenCalled();
        }
      },
    );
  });

  describe('semantic validation and failures', () => {
    it('lets an invalid body reach the use case, which answers 422 with field errors', async () => {
      test.changeTimeZone.execute.mockRejectedValue(
        new ValidationError('The request contains invalid values.', {
          timeZoneId: ['TIME_ZONE_ID_INVALID'],
        }),
      );

      const response = await call(routes[2], AUTH, { timeZoneId: 'Nope', application: 'x' });

      expect(response.statusCode).toBe(422);
      expect(response.json()).toMatchObject({
        code: 'VALIDATION_FAILED',
        fieldErrors: { timeZoneId: ['TIME_ZONE_ID_INVALID'] },
      });
    });

    it('answers 503 DEPENDENCY_UNAVAILABLE on uncertain persistence', async () => {
      test.changeTimeZone.execute.mockRejectedValue(new DependencyUnavailableError());

      const response = await call(routes[2]);

      expect(response.statusCode).toBe(503);
      expect(response.json().code).toBe('DEPENDENCY_UNAVAILABLE');
    });
  });
});
