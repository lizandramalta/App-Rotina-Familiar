/** `GET /v1/media/{mediaId}/content` (SPEC-006 CA-15, E-06): caso de uso e borda HTTP. */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { GetMediaContentUseCase } from '../../src/modules/media/application/get-media-content-use-case.js';
import type {
  MediaRepositoryPort,
  ObjectStorageReaderPort,
} from '../../src/modules/media/application/media-ports.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { buildTestApp, TEST_ACTOR, type TestApp } from '../support/build-test-app.js';

const MEDIA_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const BYTES = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x01, 0x02]);
const READY = { objectKey: 'test/media/a.jpg', contentType: 'image/jpeg', state: 'READY' };

describe('GetMediaContentUseCase — CA-15', () => {
  let findContentInFamily: ReturnType<typeof vi.fn>;
  let get: ReturnType<typeof vi.fn>;
  let useCase: GetMediaContentUseCase;

  beforeEach(() => {
    findContentInFamily = vi.fn().mockResolvedValue(READY);
    get = vi.fn().mockResolvedValue(BYTES);
    useCase = new GetMediaContentUseCase({
      repository: { findContentInFamily } as unknown as MediaRepositoryPort,
      storage: { get } as unknown as ObjectStorageReaderPort,
      transactionRunner: {
        run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
          work({ client: {} }),
        ),
      } as unknown as TransactionRunner,
    });
  });

  it('returns the bytes and content type of a READY media, looked up inside the actor family', async () => {
    const result = await useCase.execute(TEST_ACTOR, MEDIA_ID);

    expect(result).toEqual({ body: BYTES, contentType: 'image/jpeg' });
    expect(findContentInFamily).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      mediaId: MEDIA_ID,
    });
    expect(get).toHaveBeenCalledWith(READY.objectKey);
  });

  it.each([
    ['missing or from another family', undefined],
    ['UPLOADING', { ...READY, state: 'UPLOADING' }],
    ['FAILED', { ...READY, state: 'FAILED' }],
    ['DELETING', { ...READY, state: 'DELETING' }],
    ['DELETED', { ...READY, state: 'DELETED' }],
  ])('answers 404 RESOURCE_NOT_FOUND for media %s, without reading storage', async (_l, record) => {
    findContentInFamily.mockResolvedValue(record);

    const error = await useCase.execute(TEST_ACTOR, MEDIA_ID).catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
    expect(error).toMatchObject({ statusCode: 404, code: 'RESOURCE_NOT_FOUND' });
    expect(get).not.toHaveBeenCalled();
  });

  it('answers 404 for a malformed id without querying the database', async () => {
    const error = await useCase.execute(TEST_ACTOR, 'not-a-uuid').catch((e) => e);

    expect(error).toMatchObject({ statusCode: 404, code: 'RESOURCE_NOT_FOUND' });
    expect(findContentInFamily).not.toHaveBeenCalled();
  });

  it('answers 404 when the object is gone from storage', async () => {
    get.mockResolvedValue(undefined);

    await expect(useCase.execute(TEST_ACTOR, MEDIA_ID)).rejects.toMatchObject({
      statusCode: 404,
      code: 'RESOURCE_NOT_FOUND',
    });
  });
});

describe('GET /v1/media/:mediaId/content — CA-15', () => {
  let test: TestApp;
  const AUTH = { authorization: 'Bearer opaque-access-token' };
  const get = () =>
    test.app.inject({ method: 'GET', url: `/v1/media/${MEDIA_ID}/content`, headers: AUTH });

  beforeEach(() => {
    test = buildTestApp();
  });
  afterEach(async () => {
    await test.app.close();
  });

  it('streams the bytes as 200 image/jpeg with Cache-Control: private, no-store', async () => {
    test.getMediaContent.execute.mockResolvedValue({ body: BYTES, contentType: 'image/jpeg' });

    const response = await get();

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toBe('image/jpeg');
    expect(response.headers['cache-control']).toBe('private, no-store');
    expect(response.rawPayload.equals(BYTES)).toBe(true);
    expect(test.getMediaContent.execute).toHaveBeenCalledWith(TEST_ACTOR, MEDIA_ID);
  });

  it('answers 404 RESOURCE_NOT_FOUND as Problem Details', async () => {
    test.getMediaContent.execute.mockRejectedValue(new NotFoundError('Media not found.'));

    const response = await get();

    expect(response.statusCode).toBe(404);
    expect(response.json().code).toBe('RESOURCE_NOT_FOUND');
  });

  it('requires a session', async () => {
    const response = await test.app.inject({
      method: 'GET',
      url: `/v1/media/${MEDIA_ID}/content`,
    });

    expect(response.statusCode).toBe(401);
    expect(test.getMediaContent.execute).not.toHaveBeenCalled();
  });
});
