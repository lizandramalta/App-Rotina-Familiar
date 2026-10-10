/** Caso de uso `UpdateOwnProfile` no recorte da SPEC-002: vínculo da foto (CA-10). */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type {
  MediaRecord,
  MediaRepositoryPort,
} from '../../src/modules/media/application/media-ports.js';
import {
  PhotoMediaNotOwnedError,
  PhotoMediaNotReadyError,
  PhotoMediaPurposeMismatchError,
} from '../../src/modules/media/domain/media-errors.js';
import type { ProfileRepositoryPort } from '../../src/modules/profile/application/profile-repository-port.js';
import { UpdateOwnProfileUseCase } from '../../src/modules/profile/application/update-own-profile-use-case.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T12:00:00.000Z');
const MEDIA_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';

const readyOwnPhoto: MediaRecord = {
  id: MEDIA_ID,
  ownerMemberId: TEST_ACTOR.memberId,
  purpose: 'PROFILE_PHOTO',
  state: 'READY',
};

describe('UpdateOwnProfileUseCase', () => {
  let findInFamily: ReturnType<typeof vi.fn>;
  let markLinked: ReturnType<typeof vi.fn>;
  let setPhoto: ReturnType<typeof vi.fn>;
  let forFamily: ReturnType<typeof vi.fn>;
  let useCase: UpdateOwnProfileUseCase;

  beforeEach(() => {
    findInFamily = vi.fn().mockResolvedValue(readyOwnPhoto);
    markLinked = vi.fn();
    setPhoto = vi.fn();
    forFamily = vi.fn(async (_id: string, work: (tx: TransactionContext) => Promise<unknown>) =>
      work({ client: {} }),
    );

    useCase = new UpdateOwnProfileUseCase({
      profileRepository: { setPhoto } as unknown as ProfileRepositoryPort,
      mediaRepository: { findInFamily, markLinked } as unknown as MediaRepositoryPort,
      transactionRunner: { run: vi.fn(), forFamily } as unknown as TransactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
  });

  const link = (photoMediaId: string | null = MEDIA_ID) =>
    useCase.execute({ actor: TEST_ACTOR, photoMediaId });

  it('links a READY profile photo owned by the session member', async () => {
    const result = await link();

    expect(result).toEqual({ photoMediaId: MEDIA_ID });
    expect(setPhoto).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
      photoMediaId: MEDIA_ID,
      updatedAt: NOW,
    });
    expect(markLinked).toHaveBeenCalledWith(expect.anything(), {
      mediaId: MEDIA_ID,
      linkedAt: NOW,
    });
  });

  it('runs under the family lock and looks the media up inside the actor’s family', async () => {
    await link();

    expect(forFamily).toHaveBeenCalledWith(TEST_ACTOR.familyId, expect.any(Function));
    expect(findInFamily).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      mediaId: MEDIA_ID,
    });
  });

  it('removes the photo when photoMediaId is null, without touching media', async () => {
    const result = await link(null);

    expect(result).toEqual({ photoMediaId: null });
    expect(findInFamily).not.toHaveBeenCalled();
    expect(markLinked).not.toHaveBeenCalled();
    expect(setPhoto).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ photoMediaId: null }),
    );
  });

  it('answers 404 for media that does not exist or belongs to another family', async () => {
    findInFamily.mockResolvedValue(undefined);

    const error = await link().catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
    expect(error).toMatchObject({ statusCode: 404, code: 'RESOURCE_NOT_FOUND' });
    expect(setPhoto).not.toHaveBeenCalled();
  });

  it('answers 422 PHOTO_MEDIA_NOT_OWNED for another member’s media in the same family', async () => {
    findInFamily.mockResolvedValue({ ...readyOwnPhoto, ownerMemberId: 'someone-else' });

    const error = await link().catch((e) => e);

    expect(error).toBeInstanceOf(PhotoMediaNotOwnedError);
    expect(error).toMatchObject({ statusCode: 422, code: 'PHOTO_MEDIA_NOT_OWNED' });
    expect(setPhoto).not.toHaveBeenCalled();
  });

  it('answers 422 PHOTO_MEDIA_PURPOSE_MISMATCH for media uploaded for another purpose', async () => {
    findInFamily.mockResolvedValue({ ...readyOwnPhoto, purpose: 'TASK_SIGNAL' });

    const error = await link().catch((e) => e);

    expect(error).toBeInstanceOf(PhotoMediaPurposeMismatchError);
    expect(error).toMatchObject({ statusCode: 422, code: 'PHOTO_MEDIA_PURPOSE_MISMATCH' });
    expect(setPhoto).not.toHaveBeenCalled();
  });

  it.each(['UPLOADING', 'FAILED', 'DELETING', 'DELETED'])(
    'answers 422 PHOTO_MEDIA_NOT_READY for media in state %s',
    async (state) => {
      findInFamily.mockResolvedValue({ ...readyOwnPhoto, state });

      const error = await link().catch((e) => e);

      expect(error).toBeInstanceOf(PhotoMediaNotReadyError);
      expect(error).toMatchObject({ statusCode: 422, code: 'PHOTO_MEDIA_NOT_READY' });
      expect(setPhoto).not.toHaveBeenCalled();
    },
  );

  it('checks ownership before readiness, so foreign media never reveals its state', async () => {
    findInFamily.mockResolvedValue({
      ...readyOwnPhoto,
      ownerMemberId: 'someone-else',
      state: 'UPLOADING',
    });

    await expect(link()).rejects.toBeInstanceOf(PhotoMediaNotOwnedError);
  });
});
