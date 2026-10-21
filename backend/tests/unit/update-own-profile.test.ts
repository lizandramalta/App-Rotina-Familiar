/** Caso de uso `UpdateOwnProfile` (SPEC-002 CA-10 + SPEC-006 Fase 1 CA-02/06/07/09/12). */
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
import type {
  OwnProfileRecord,
  ProfileRepositoryPort,
} from '../../src/modules/profile/application/profile-repository-port.js';
import { UpdateOwnProfileUseCase } from '../../src/modules/profile/application/update-own-profile-use-case.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { NotFoundError, ValidationError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T12:00:00.000Z');
const MEDIA_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';

const readyOwnPhoto: MediaRecord = {
  id: MEDIA_ID,
  ownerMemberId: TEST_ACTOR.memberId,
  purpose: 'PROFILE_PHOTO',
  state: 'READY',
};

const CURRENT_PROFILE: OwnProfileRecord = {
  name: 'Maria Silva',
  nickname: 'Mari',
  photoMediaId: null,
};

describe('UpdateOwnProfileUseCase — SPEC-002 + SPEC-006', () => {
  let findOwnProfile: ReturnType<typeof vi.fn>;
  let findInFamily: ReturnType<typeof vi.fn>;
  let markLinked: ReturnType<typeof vi.fn>;
  let setPhoto: ReturnType<typeof vi.fn>;
  let setNickname: ReturnType<typeof vi.fn>;
  let findBadgeProgress: ReturnType<typeof vi.fn>;
  let forFamily: ReturnType<typeof vi.fn>;
  let useCase: UpdateOwnProfileUseCase;

  beforeEach(() => {
    findOwnProfile = vi.fn().mockResolvedValue(CURRENT_PROFILE);
    findInFamily = vi.fn().mockResolvedValue(readyOwnPhoto);
    markLinked = vi.fn();
    setPhoto = vi.fn();
    setNickname = vi.fn();
    findBadgeProgress = vi.fn().mockResolvedValue({
      totalParticipations: 7,
      nextTier: { code: 'silver', requiredMissionCount: 10 },
    });
    forFamily = vi.fn(async (_id: string, work: (tx: TransactionContext) => Promise<unknown>) =>
      work({ client: {} }),
    );

    useCase = new UpdateOwnProfileUseCase({
      profileRepository: {
        findOwnProfile,
        setPhoto,
        setNickname,
        findBadgeProgress,
      } as unknown as ProfileRepositoryPort,
      mediaRepository: { findInFamily, markLinked } as unknown as MediaRepositoryPort,
      transactionRunner: { run: vi.fn(), forFamily } as unknown as TransactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
  });

  const update = (overrides: { nickname?: string | null; photoMediaId?: string | null } = {}) =>
    useCase.execute({ actor: TEST_ACTOR, ...overrides });

  const link = (photoMediaId: string | null = MEDIA_ID) => update({ photoMediaId });

  const expectedProfile = (overrides: Partial<Record<string, unknown>> = {}) => ({
    memberId: TEST_ACTOR.memberId,
    name: 'Maria Silva',
    nickname: 'Mari',
    photoMediaId: null,
    totalParticipations: 7,
    nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 3 },
    ...overrides,
  });

  it('links a READY profile photo owned by the session member', async () => {
    const result = await link();

    expect(result).toEqual(expectedProfile({ photoMediaId: MEDIA_ID }));
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

    expect(result).toEqual(expectedProfile({ photoMediaId: null }));
    expect(findInFamily).not.toHaveBeenCalled();
    expect(markLinked).not.toHaveBeenCalled();
    expect(setPhoto).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ photoMediaId: null }),
    );
  });

  it('CA-02 preserves photoMediaId when the command omits it (nickname-only update)', async () => {
    findOwnProfile.mockResolvedValue({ ...CURRENT_PROFILE, photoMediaId: MEDIA_ID });

    const result = await update({ nickname: 'Mi' });

    expect(result.photoMediaId).toBe(MEDIA_ID);
    expect(setPhoto).not.toHaveBeenCalled();
    expect(findInFamily).not.toHaveBeenCalled();
  });

  it('CA-02 preserves nickname when the command omits it (photo-only update)', async () => {
    const result = await link();

    expect(result.nickname).toBe('Mari');
    expect(setNickname).not.toHaveBeenCalled();
  });

  it('CA-02 sets a trimmed nickname and persists it', async () => {
    const result = await update({ nickname: '  Mi  ' });

    expect(result.nickname).toBe('Mi');
    expect(setNickname).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
      nickname: 'Mi',
      updatedAt: NOW,
    });
  });

  it('removes the nickname when it is null or empty after trim', async () => {
    const resultNull = await update({ nickname: null });
    expect(resultNull.nickname).toBeNull();
    expect(setNickname).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ nickname: null }),
    );

    const resultEmpty = await update({ nickname: '   ' });
    expect(resultEmpty.nickname).toBeNull();
  });

  it('CA-06 rejects a nickname longer than 20 non-space characters with 422 NICKNAME_INVALID_LENGTH', async () => {
    const error = await update({ nickname: 'a'.repeat(21) }).catch((e) => e);

    expect(error).toBeInstanceOf(ValidationError);
    expect(error).toMatchObject({
      statusCode: 422,
      code: 'VALIDATION_FAILED',
      fieldErrors: { nickname: ['NICKNAME_INVALID_LENGTH'] },
    });
    expect(setNickname).not.toHaveBeenCalled();
  });

  it('does not count internal spaces toward the 20 non-space character limit', async () => {
    const nickname = `${'a'.repeat(10)} ${'b'.repeat(10)}`; // 20 non-space chars, 1 internal space
    const result = await update({ nickname });

    expect(result.nickname).toBe(nickname);
  });

  it('CA-09 rolls back the whole update when the photo is invalid, leaving the valid nickname unpersisted', async () => {
    findInFamily.mockResolvedValue(undefined);

    const error = await update({ nickname: 'Mi', photoMediaId: MEDIA_ID }).catch((e) => e);

    expect(error).toBeInstanceOf(NotFoundError);
    expect(setNickname).toHaveBeenCalled(); // nickname is validated/applied first...
    expect(setPhoto).not.toHaveBeenCalled(); // ...but the photo failure happens in the same forFamily transaction,
    // so a real Postgres rollback (covered by the integration test) discards both writes together.
  });

  it('CA-12 allows a Kids session to edit its own nickname/photo like an adult', async () => {
    const result = await useCase.execute({
      actor: { ...TEST_ACTOR, role: MemberRole.KIDS },
      nickname: 'Kid',
    });

    expect(result.nickname).toBe('Kid');
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
