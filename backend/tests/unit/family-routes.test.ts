/**
 * `POST /v1/families` na borda HTTP (SPEC-002 §5.2/§5.3): CA-01, CA-02 e CA-04.
 * O caso de uso é dublê; a regra de negócio está em create-family.test.ts.
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { CreationGrantInvalidError } from '../../src/modules/family/domain/family-errors.js';
import {
  DependencyUnavailableError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { buildTestApp, type TestApp } from '../support/build-test-app.js';

const BODY = {
  creationGrant: 'opaque-grant',
  creatorName: 'Maria Silva',
  creatorNickname: 'Mari',
  name: 'Casa Silva',
  timeZoneId: 'America/Sao_Paulo',
};

const HEADERS = { 'x-installation-proof': 'installation-proof' };

const RESULT = {
  family: {
    id: 'f-1',
    name: 'Casa Silva',
    timeZoneId: 'America/Sao_Paulo',
    createdAt: '2026-10-06T12:00:00.000Z',
  },
  member: {
    id: 'm-1',
    name: 'Maria Silva',
    nickname: 'Mari',
    role: 'administrator',
    isFamilyCreator: true,
  },
  initialMembers: [],
  session: {
    sessionId: 's-1',
    memberId: 'm-1',
    familyId: 'f-1',
    role: 'administrator',
    isFamilyCreator: true,
    accessToken: 'opaque-access',
    accessTokenExpiresAt: '2026-10-06T12:15:00.000Z',
    refreshToken: 'opaque-refresh',
  },
};

describe('POST /v1/families', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.createFamily.execute.mockResolvedValue(RESULT);
  });

  afterEach(async () => {
    await test.app.close();
  });

  const post = (body: unknown, headers: Record<string, string> = HEADERS) =>
    test.app.inject({ method: 'POST', url: '/v1/families', headers, payload: body as object });

  describe('CA-01: success', () => {
    it('documents initial members, optional photo and response in OpenAPI', async () => {
      const docs = await test.app.inject({ method: 'GET', url: '/docs/json' });
      const operation = docs.json().paths['/v1/families'].post;
      const body = operation.requestBody.content['application/json'].schema;
      expect(body.properties.initialMembers.items.properties.role.enum).toEqual([
        'administrator',
        'member',
        'kids',
      ]);
      expect(body.properties.creatorPhotoMediaId.format).toBe('uuid');
      expect(
        operation.responses['201'].content['application/json'].schema.properties.initialMembers,
      ).toBeDefined();
    });
    it('answers 201 with Location, no-store and the family, member and session', async () => {
      const response = await post(BODY);

      expect(response.statusCode).toBe(201);
      expect(response.headers.location).toBe('/v1/family');
      expect(response.headers['cache-control']).toBe('no-store');
      expect(response.json()).toEqual(RESULT);
    });

    it('does not use a member Bearer: the creationGrant in the body is the credential', async () => {
      await post(BODY);

      expect(test.authenticateSession.execute).not.toHaveBeenCalled();
    });

    it('forwards the body fields and the installation proof header to the use case', async () => {
      await post(BODY);

      expect(test.createFamily.execute).toHaveBeenCalledWith({
        creationGrant: 'opaque-grant',
        creatorName: 'Maria Silva',
        creatorNickname: 'Mari',
        name: 'Casa Silva',
        timeZoneId: 'America/Sao_Paulo',
        installationProof: 'installation-proof',
      });
    });

    it('accepts a body without timeZoneId and without nickname', async () => {
      const response = await post({
        creationGrant: 'opaque-grant',
        creatorName: 'Maria',
        name: 'Casa',
      });

      expect(response.statusCode).toBe(201);
    });

    it('accepts a null nickname', async () => {
      const response = await post({ ...BODY, creatorNickname: null });

      expect(response.statusCode).toBe(201);
      expect(test.createFamily.execute.mock.calls[0]?.[0].creatorNickname).toBeNull();
    });
  });

  describe('CA-04: unknown and protected fields are rejected, not ignored', () => {
    it.each(['familyId', 'memberId', 'role', 'isFamilyCreator', 'state', 'photoMediaId'])(
      'rejects %s with 400 UNKNOWN_FIELD naming the field',
      async (field) => {
        const response = await post({ ...BODY, [field]: 'attacker-controlled' });

        expect(response.statusCode).toBe(400);
        expect(response.headers['content-type']).toContain('application/problem+json');
        expect(response.json()).toMatchObject({
          status: 400,
          code: 'UNKNOWN_FIELD',
          fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
        });
        expect(test.createFamily.execute).not.toHaveBeenCalled();
      },
    );

    it('answers CREATION_GRANT_INVALID as 401 problem+json', async () => {
      test.createFamily.execute.mockRejectedValue(new CreationGrantInvalidError());

      const response = await post(BODY);

      expect(response.statusCode).toBe(401);
      expect(response.headers['content-type']).toContain('application/problem+json');
      expect(response.json()).toMatchObject({
        status: 401,
        code: 'CREATION_GRANT_INVALID',
      });
      expect(response.json().requestId).toEqual(expect.any(String));
    });

    it('treats a missing grant as an invalid grant (401), not a schema error', async () => {
      test.createFamily.execute.mockRejectedValue(new CreationGrantInvalidError());
      const { creationGrant: _omitted, ...withoutGrant } = BODY;

      const response = await post(withoutGrant);

      expect(response.statusCode).toBe(401);
      expect(test.createFamily.execute.mock.calls[0]?.[0].creationGrant).toBeUndefined();
    });

    it('requires the installation proof header', async () => {
      const response = await post(BODY, {});

      expect(response.statusCode).toBe(400);
      expect(response.json().code).toBe('VALIDATION_FAILED');
      expect(test.createFamily.execute).not.toHaveBeenCalled();
    });
  });

  describe('CA-02: semantic validation answers 422 with field errors', () => {
    it('maps a ValidationError to 422 VALIDATION_FAILED with fieldErrors', async () => {
      test.createFamily.execute.mockRejectedValue(
        new ValidationError('The request contains invalid values.', {
          name: ['FAMILY_NAME_REQUIRED'],
        }),
      );

      const response = await post({ ...BODY, name: '' });

      expect(response.statusCode).toBe(422);
      expect(response.json()).toMatchObject({
        status: 422,
        code: 'VALIDATION_FAILED',
        fieldErrors: { name: ['FAMILY_NAME_REQUIRED'] },
      });
    });

    it('lets an empty name reach the use case instead of failing in the schema', async () => {
      await post({ ...BODY, name: '' });

      expect(test.createFamily.execute).toHaveBeenCalledTimes(1);
    });
  });

  describe('CA-09: uncertain persistence', () => {
    it('answers 503 DEPENDENCY_UNAVAILABLE', async () => {
      test.createFamily.execute.mockRejectedValue(new DependencyUnavailableError());

      const response = await post(BODY);

      expect(response.statusCode).toBe(503);
      expect(response.json().code).toBe('DEPENDENCY_UNAVAILABLE');
    });
  });
});
