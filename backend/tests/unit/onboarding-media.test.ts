/** SCRUM-106 / SPEC-002 CA-10: protected photo upload and orphan cleanup. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CleanOrphanOnboardingMedia } from '../../src/modules/media/application/clean-orphan-onboarding-media.js';
import { UploadOnboardingMediaUseCase } from '../../src/modules/media/application/upload-onboarding-media-use-case.js';
import type { ObjectStorageMaintenancePort } from '../../src/modules/media/application/media-ports.js';
import type { OnboardingMediaPort } from '../../src/modules/media/application/onboarding-media-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { CreationGrantInvalidError } from '../../src/modules/family/domain/family-errors.js';
import { DependencyUnavailableError } from '../../src/shared/domain/domain-error.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const tx: TransactionContext = { client: {} };
const runner: TransactionRunner = {
  run: async (work) => work(tx),
  forFamily: async (_id, work) => work(tx),
};
const now = new Date('2026-10-19T12:00:00.000Z');
const clock = { now: () => now, nowIsoString: () => now.toISOString() };
const processed = {
  body: Buffer.from('jpeg'),
  contentType: 'image/jpeg' as const,
  sizeBytes: 4,
  width: 8,
  height: 8,
};

describe('onboarding media', () => {
  let repository: { [K in keyof OnboardingMediaPort]: ReturnType<typeof vi.fn> };
  let storage: { put: ReturnType<typeof vi.fn>; delete: ReturnType<typeof vi.fn> };
  let upload: UploadOnboardingMediaUseCase;

  beforeEach(() => {
    repository = {
      findUsableGrant: vi.fn().mockResolvedValue('grant-id'),
      reserve: vi.fn(),
      markReady: vi.fn(),
      markFailed: vi.fn(),
      findForGrant: vi.fn(),
      findById: vi.fn(),
      transferToCreator: vi.fn(),
      claimExpired: vi.fn().mockResolvedValue([]),
      deleteClaimed: vi.fn(),
    };
    storage = { put: vi.fn(), delete: vi.fn() };
    const { logger } = createRecordingLogger();
    upload = new UploadOnboardingMediaUseCase({
      repository: repository as unknown as OnboardingMediaPort,
      storage: storage as unknown as ObjectStorageMaintenancePort,
      imageProcessor: { processProfilePhoto: vi.fn().mockResolvedValue(processed) },
      crypto: { newId: () => 'media-id', hashToken: (value) => `hash:${value}` },
      transactionRunner: runner,
      clock,
      logger,
      keyPrefix: 'test',
    });
  });

  const command = {
    creationGrant: 'grant-token',
    installationProof: 'device-proof',
    purpose: 'profilePhoto',
    content: Buffer.from('raw'),
  };

  it('reserves media for the validated grant before R2 and marks it READY', async () => {
    await expect(upload.execute(command)).resolves.toEqual({
      mediaId: 'media-id',
      state: 'READY',
      width: 8,
      height: 8,
    });
    expect(repository.findUsableGrant).toHaveBeenCalledWith(
      tx,
      'hash:grant-token',
      'hash:device-proof',
      now,
    );
    expect(repository.reserve).toHaveBeenCalledWith(tx, {
      id: 'media-id',
      grantId: 'grant-id',
      objectKey: 'test/onboarding/profile-photos/media-id.jpg',
    });
    expect(storage.put).toHaveBeenCalledWith({
      key: 'test/onboarding/profile-photos/media-id.jpg',
      body: processed.body,
      contentType: 'image/jpeg',
    });
    expect(repository.markReady).toHaveBeenCalledWith(tx, {
      id: 'media-id',
      sizeBytes: 4,
      contentType: 'image/jpeg',
    });
  });

  it('rejects a different installation or expired grant before storing bytes', async () => {
    repository.findUsableGrant.mockResolvedValue(undefined);
    await expect(upload.execute(command)).rejects.toBeInstanceOf(CreationGrantInvalidError);
    expect(storage.put).not.toHaveBeenCalled();
  });

  it('keeps failure recoverable when R2 fails', async () => {
    storage.put.mockRejectedValue(new Error('R2 unavailable'));
    await expect(upload.execute(command)).rejects.toBeInstanceOf(DependencyUnavailableError);
    expect(repository.markFailed).toHaveBeenCalledWith(tx, 'media-id');
  });

  it('cleans only claimed old unlinked media and retries after a delete failure', async () => {
    const media = {
      id: 'old-media',
      grantId: 'grant-id',
      objectKey: 'test/onboarding/old.jpg',
      purpose: 'PROFILE_PHOTO',
      state: 'DELETING',
      sizeBytes: null,
      contentType: null,
    };
    repository.claimExpired.mockResolvedValue([media]);
    const { logger } = createRecordingLogger();
    const clean = new CleanOrphanOnboardingMedia({
      repository: repository as unknown as OnboardingMediaPort,
      storage: storage as unknown as ObjectStorageMaintenancePort,
      transactionRunner: runner,
      clock,
      logger,
    });
    storage.delete.mockRejectedValueOnce(new Error('R2 down'));
    await clean.run();
    expect(repository.deleteClaimed).not.toHaveBeenCalled();
    await clean.run();
    expect(repository.claimExpired).toHaveBeenCalledWith(
      tx,
      new Date('2026-10-18T12:00:00.000Z'),
      50,
    );
    expect(repository.deleteClaimed).toHaveBeenCalledWith(tx, 'old-media');
  });
});
