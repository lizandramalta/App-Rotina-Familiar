/** Caso de uso `UploadMedia` (SPEC-002 §5.2, backend-architecture.md §13): CA-10. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type {
  ImageProcessorPort,
  MediaRepositoryPort,
  ObjectStoragePort,
} from '../../src/modules/media/application/media-ports.js';
import { UploadMediaUseCase } from '../../src/modules/media/application/upload-media-use-case.js';
import { MediaFormatUnsupportedError } from '../../src/modules/media/domain/media-errors.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { createRecordingLogger } from '../support/fake-logger.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const PROCESSED = {
  body: Buffer.from('jpeg-bytes'),
  contentType: 'image/jpeg' as const,
  sizeBytes: 10,
  width: 800,
  height: 600,
};

describe('UploadMediaUseCase', () => {
  let events: string[];
  let repository: { [K in keyof MediaRepositoryPort]: ReturnType<typeof vi.fn> };
  let storage: { put: ReturnType<typeof vi.fn> };
  let imageProcessor: { processProfilePhoto: ReturnType<typeof vi.fn> };
  let useCase: UploadMediaUseCase;
  let logCalls: unknown[][];

  beforeEach(() => {
    events = [];
    repository = {
      reserve: vi.fn(async () => void events.push('reserve')),
      markReady: vi.fn(async () => void events.push('markReady')),
      markFailed: vi.fn(async () => void events.push('markFailed')),
      findInFamily: vi.fn(),
      findContentInFamily: vi.fn(),
      markLinked: vi.fn(),
    };
    storage = { put: vi.fn(async () => void events.push('put')) };
    imageProcessor = { processProfilePhoto: vi.fn().mockResolvedValue(PROCESSED) };

    const runner: TransactionRunner = {
      run: async <T>(work: (tx: TransactionContext) => Promise<T>) => work({ client: {} }),
      forFamily: async <T>(_id: string, work: (tx: TransactionContext) => Promise<T>) =>
        work({ client: {} }),
    };
    const { logger, calls } = createRecordingLogger();
    logCalls = calls;

    useCase = new UploadMediaUseCase({
      repository: repository as unknown as MediaRepositoryPort,
      storage: storage as unknown as ObjectStoragePort,
      imageProcessor: imageProcessor as unknown as ImageProcessorPort,
      crypto: { newId: () => 'media-1' },
      transactionRunner: runner,
      logger,
      keyPrefix: 'test',
    });
  });

  const upload = (...args: [purpose?: unknown]) =>
    useCase.execute({
      actor: TEST_ACTOR,
      purpose: args.length === 0 ? 'profilePhoto' : args[0],
      content: Buffer.from('raw-image'),
    });

  it('reserves, writes the object, then marks the media ready — in that order', async () => {
    const result = await upload();

    expect(events).toEqual(['reserve', 'put', 'markReady']);
    expect(result).toEqual({ mediaId: 'media-1', state: 'READY', width: 800, height: 600 });
  });

  it('reserves the media under the session’s family and member, never client-provided ids', async () => {
    await upload();

    expect(repository.reserve).toHaveBeenCalledWith(expect.anything(), {
      mediaId: 'media-1',
      familyId: TEST_ACTOR.familyId,
      ownerMemberId: TEST_ACTOR.memberId,
      objectKey: `test/families/${TEST_ACTOR.familyId}/profile-photos/media-1.jpg`,
      purpose: 'PROFILE_PHOTO',
    });
  });

  it('stores the processed JPEG, not the original upload', async () => {
    await upload();

    expect(imageProcessor.processProfilePhoto).toHaveBeenCalledWith(Buffer.from('raw-image'));
    expect(storage.put).toHaveBeenCalledWith({
      key: `test/families/${TEST_ACTOR.familyId}/profile-photos/media-1.jpg`,
      body: PROCESSED.body,
      contentType: 'image/jpeg',
    });
    expect(repository.markReady).toHaveBeenCalledWith(expect.anything(), {
      mediaId: 'media-1',
      sizeBytes: 10,
      contentType: 'image/jpeg',
    });
  });

  it.each([['taskSignal'], [undefined], ['avatar'], [42]])(
    'accepts only the profilePhoto purpose (rejects %j)',
    async (purpose) => {
      const error = await upload(purpose).catch((e) => e);

      expect(error).toBeInstanceOf(ValidationError);
      expect(error.fieldErrors).toEqual({ purpose: ['MEDIA_PURPOSE_INVALID'] });
      expect(repository.reserve).not.toHaveBeenCalled();
    },
  );

  it('does not reserve or write anything when the image cannot be decoded', async () => {
    imageProcessor.processProfilePhoto.mockRejectedValue(new MediaFormatUnsupportedError());

    await expect(upload()).rejects.toBeInstanceOf(MediaFormatUnsupportedError);
    expect(events).toEqual([]);
  });

  it('marks the media FAILED and answers 503 when the object write fails', async () => {
    storage.put.mockRejectedValue(new Error('r2 timeout'));

    const error = await upload().catch((e) => e);

    expect(error).toBeInstanceOf(DependencyUnavailableError);
    expect(events).toEqual(['reserve', 'markFailed']);
    expect(repository.markReady).not.toHaveBeenCalled();
  });

  it('answers 503 when the reservation cannot be saved, without touching storage', async () => {
    repository.reserve.mockRejectedValue(new Error('db down'));

    await expect(upload()).rejects.toBeInstanceOf(DependencyUnavailableError);
    expect(storage.put).not.toHaveBeenCalled();
  });

  it('answers 503 if the ready transition fails after the object was written', async () => {
    repository.markReady.mockRejectedValue(new Error('db down'));

    await expect(upload()).rejects.toBeInstanceOf(DependencyUnavailableError);
    // O objeto existe e a mídia segue UPLOADING: o worker reconcilia (§13).
    expect(events).toEqual(['reserve', 'put']);
  });

  it('does not log image content', async () => {
    storage.put.mockRejectedValue(new Error('r2 timeout'));
    await upload().catch(() => undefined);

    expect(JSON.stringify(logCalls)).not.toContain('raw-image');
    expect(JSON.stringify(logCalls)).not.toContain('jpeg-bytes');
  });
});
