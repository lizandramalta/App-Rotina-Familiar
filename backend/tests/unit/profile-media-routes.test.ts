/** `PATCH /v1/me/profile` e `POST /v1/media` na borda HTTP (SPEC-002 §5.2/§5.3, SPEC-006 CA-02/03/06/07). */
import sharp from 'sharp';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  MediaFormatUnsupportedError,
  MediaTooLargeError,
  PhotoMediaNotOwnedError,
} from '../../src/modules/media/domain/media-errors.js';
import { MAX_UPLOAD_INPUT_BYTES } from '../../src/presentation/http/media-routes.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  NotFoundError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const OWN_PROFILE_RESULT = {
  memberId: TEST_ACTOR.memberId,
  name: 'Maria Silva',
  familyName: 'Família Silva',
  nickname: 'Mari',
  photoMediaId: null as string | null,
  totalParticipations: 7,
  nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 3 },
};

const AUTH = { authorization: 'Bearer opaque-access-token' };
const MEDIA_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const BOUNDARY = 'testboundary123';

function multipartBody(parts: { name: string; value: string | Buffer; filename?: string }[]) {
  const chunks: Buffer[] = [];
  for (const part of parts) {
    const disposition =
      part.filename === undefined
        ? `form-data; name="${part.name}"`
        : `form-data; name="${part.name}"; filename="${part.filename}"`;
    const contentType = part.filename === undefined ? '' : 'Content-Type: image/png\r\n';
    chunks.push(
      Buffer.from(`--${BOUNDARY}\r\nContent-Disposition: ${disposition}\r\n${contentType}\r\n`),
      Buffer.isBuffer(part.value) ? part.value : Buffer.from(part.value),
      Buffer.from('\r\n'),
    );
  }
  chunks.push(Buffer.from(`--${BOUNDARY}--\r\n`));
  return Buffer.concat(chunks);
}

describe('PATCH /v1/me/profile', () => {
  let test: TestApp;

  beforeEach(() => {
    test = buildTestApp();
    test.updateOwnProfile.execute.mockResolvedValue({
      ...OWN_PROFILE_RESULT,
      photoMediaId: MEDIA_ID,
    });
  });
  afterEach(async () => {
    await test.app.close();
  });

  const patch = (payload: unknown) =>
    test.app.inject({
      method: 'PATCH',
      url: '/v1/me/profile',
      headers: AUTH,
      payload: payload as object,
    });

  it('links the photo and answers 200 with no-store, with the canonical profile', async () => {
    const response = await patch({ photoMediaId: MEDIA_ID });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual({ ...OWN_PROFILE_RESULT, photoMediaId: MEDIA_ID });
    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      name: undefined,
      nickname: undefined,
      photoMediaId: MEDIA_ID,
    });
  });

  it('removes the photo with null', async () => {
    test.updateOwnProfile.execute.mockResolvedValue(OWN_PROFILE_RESULT);

    const response = await patch({ photoMediaId: null });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual(OWN_PROFILE_RESULT);
  });

  it('CA-02 sends only nickname, leaving photoMediaId out of the command entirely', async () => {
    test.updateOwnProfile.execute.mockResolvedValue({ ...OWN_PROFILE_RESULT, nickname: 'Mi' });

    const response = await patch({ nickname: 'Mi' });

    expect(response.statusCode).toBe(200);
    expect(response.json().nickname).toBe('Mi');
    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      name: undefined,
      nickname: 'Mi',
      photoMediaId: undefined,
    });
  });

  it('CA-02 accepts an empty body: both fields stay omitted, preserving current values', async () => {
    const response = await patch({});

    expect(response.statusCode).toBe(200);
    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      name: undefined,
      nickname: undefined,
      photoMediaId: undefined,
    });
  });

  it.each([
    'familyId',
    'memberId',
    'role',
    'kidsMode',
    'isFamilyCreator',
    'appleUserID',
    'status',
    'concededAt',
    'contributingMissionIds',
  ])(
    'CA-03 rejects protected field %s with 400 UNKNOWN_FIELD, without persisting',
    async (field) => {
      const response = await patch({ photoMediaId: MEDIA_ID, [field]: 'x' });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'UNKNOWN_FIELD',
        fieldErrors: { [field]: ['UNKNOWN_FIELD'] },
      });
      expect(test.updateOwnProfile.execute).not.toHaveBeenCalled();
    },
  );

  it('rejects an invalid photoMediaId format with 400 VALIDATION_FAILED', async () => {
    const response = await patch({ photoMediaId: 'not-a-uuid' });

    expect(response.statusCode).toBe(400);
    expect(response.json().code).toBe('VALIDATION_FAILED');
  });

  it('CA-06 maps NICKNAME_INVALID_LENGTH to 422 VALIDATION_FAILED', async () => {
    test.updateOwnProfile.execute.mockRejectedValueOnce(
      new ValidationError('The nickname is invalid.', { nickname: ['NICKNAME_INVALID_LENGTH'] }),
    );

    const response = await patch({ nickname: 'a'.repeat(21) });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { nickname: ['NICKNAME_INVALID_LENGTH'] },
    });
  });

  it('CA-02 forwards name to the use case', async () => {
    await patch({ name: 'Maria S.' });

    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith({
      actor: TEST_ACTOR,
      name: 'Maria S.',
      nickname: undefined,
      photoMediaId: undefined,
    });
  });

  it('CA-13 maps NAME_INVALID_LENGTH to 422 VALIDATION_FAILED, including a null name', async () => {
    test.updateOwnProfile.execute.mockRejectedValueOnce(
      new ValidationError('The name is invalid.', { name: ['NAME_INVALID_LENGTH'] }),
    );

    const response = await patch({ name: null });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { name: ['NAME_INVALID_LENGTH'] },
    });
    expect(test.updateOwnProfile.execute).toHaveBeenCalledWith(
      expect.objectContaining({ name: null }),
    );
  });

  it('CA-14 maps a Kids rejection to 403 ACTION_NOT_ALLOWED', async () => {
    test.updateOwnProfile.execute.mockRejectedValueOnce(new ActionNotAllowedError());

    const response = await patch({ name: 'Kid' });

    expect(response.statusCode).toBe(403);
    expect(response.json().code).toBe('ACTION_NOT_ALLOWED');
  });

  it('maps domain errors to their contract status', async () => {
    test.updateOwnProfile.execute.mockRejectedValueOnce(new PhotoMediaNotOwnedError());
    const notOwned = await patch({ photoMediaId: MEDIA_ID });
    expect(notOwned.statusCode).toBe(422);
    expect(notOwned.json().code).toBe('PHOTO_MEDIA_NOT_OWNED');

    test.updateOwnProfile.execute.mockRejectedValueOnce(new NotFoundError('Media not found.'));
    const missing = await patch({ photoMediaId: MEDIA_ID });
    expect(missing.statusCode).toBe(404);
    expect(missing.json().code).toBe('RESOURCE_NOT_FOUND');
  });
});

describe('POST /v1/media', () => {
  let test: TestApp;
  let png: Buffer;

  beforeEach(async () => {
    test = buildTestApp();
    test.uploadMedia.execute.mockResolvedValue({
      mediaId: MEDIA_ID,
      state: 'READY',
      width: 8,
      height: 8,
    });
    png = await sharp({
      create: { width: 8, height: 8, channels: 3, background: '#09f' },
    })
      .png()
      .toBuffer();
  });
  afterEach(async () => {
    await test.app.close();
  });

  const upload = (body: Buffer, headers: Record<string, string> = {}) =>
    test.app.inject({
      method: 'POST',
      url: '/v1/media',
      headers: {
        ...AUTH,
        'content-type': `multipart/form-data; boundary=${BOUNDARY}`,
        ...headers,
      },
      payload: body,
    });

  it('answers 201 with the media id, state and dimensions, and passes the file to the use case', async () => {
    const response = await upload(
      multipartBody([
        { name: 'purpose', value: 'profilePhoto' },
        { name: 'file', value: png, filename: 'me.png' },
      ]),
    );

    expect(response.statusCode).toBe(201);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual({ mediaId: MEDIA_ID, state: 'READY', width: 8, height: 8 });

    const command = test.uploadMedia.execute.mock.calls[0]?.[0];
    expect(command.actor).toEqual(TEST_ACTOR);
    expect(command.purpose).toBe('profilePhoto');
    expect(Buffer.compare(command.content, png)).toBe(0);
  });

  it('ignores any familyId or memberId field in the form: the actor comes from the session', async () => {
    await upload(
      multipartBody([
        { name: 'purpose', value: 'profilePhoto' },
        { name: 'familyId', value: 'victim-family' },
        { name: 'file', value: png, filename: 'me.png' },
      ]),
    );

    expect(test.uploadMedia.execute.mock.calls[0]?.[0].actor).toEqual(TEST_ACTOR);
  });

  it('answers 422 when the request has no file', async () => {
    const response = await upload(multipartBody([{ name: 'purpose', value: 'profilePhoto' }]));

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { file: ['MEDIA_FILE_REQUIRED'] },
    });
    expect(test.uploadMedia.execute).not.toHaveBeenCalled();
  });

  it('answers 422 when the request is not multipart', async () => {
    const response = await test.app.inject({
      method: 'POST',
      url: '/v1/media',
      headers: AUTH,
      payload: { purpose: 'profilePhoto' },
    });

    expect(response.statusCode).toBe(422);
    expect(response.json().code).toBe('VALIDATION_FAILED');
  });

  it('answers 413 MEDIA_TOO_LARGE when the file exceeds the input limit', async () => {
    const oversized = Buffer.alloc(MAX_UPLOAD_INPUT_BYTES + 1024, 1);

    const response = await upload(
      multipartBody([
        { name: 'purpose', value: 'profilePhoto' },
        { name: 'file', value: oversized, filename: 'big.png' },
      ]),
    );

    expect(response.statusCode).toBe(413);
    expect(response.json().code).toBe('MEDIA_TOO_LARGE');
    expect(test.uploadMedia.execute).not.toHaveBeenCalled();
  });

  it('maps the use case errors to their contract status', async () => {
    const body = multipartBody([
      { name: 'purpose', value: 'profilePhoto' },
      { name: 'file', value: png, filename: 'me.png' },
    ]);

    test.uploadMedia.execute.mockRejectedValueOnce(new MediaFormatUnsupportedError());
    expect((await upload(body)).statusCode).toBe(415);

    test.uploadMedia.execute.mockRejectedValueOnce(new MediaTooLargeError());
    expect((await upload(body)).statusCode).toBe(413);

    test.uploadMedia.execute.mockRejectedValueOnce(new DependencyUnavailableError());
    const unavailable = await upload(body);
    expect(unavailable.statusCode).toBe(503);
    expect(unavailable.json().code).toBe('DEPENDENCY_UNAVAILABLE');
  });
});
