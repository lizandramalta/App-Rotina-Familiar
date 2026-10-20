/** SCRUM-106 / SPEC-002 CA-12: read existing family and update only an authorized name. */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  GetFamilyUseCase,
  UpdateFamilyUseCase,
} from '../../src/modules/family/application/family-profile-use-cases.js';
import type { FamilyProfileRepositoryPort } from '../../src/modules/family/application/family-profile-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { ActionNotAllowedError, ValidationError } from '../../src/shared/domain/domain-error.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const family = { id: TEST_ACTOR.familyId, name: 'Casa Silva', timeZoneId: 'America/Sao_Paulo' };
const tx: TransactionContext = { client: {} };
const runner: TransactionRunner = {
  run: async (work) => work(tx),
  forFamily: async (_id, work) => work(tx),
};

describe('GetFamily and UpdateFamily', () => {
  let repository: { [K in keyof FamilyProfileRepositoryPort]: ReturnType<typeof vi.fn> };
  beforeEach(() => {
    repository = {
      findFamily: vi.fn().mockResolvedValue(family),
      lockFamily: vi.fn().mockResolvedValue(family),
      findActorRole: vi.fn().mockResolvedValue('administrator'),
      updateName: vi.fn().mockResolvedValue({ ...family, name: 'Nova Casa' }),
    };
  });

  const get = () =>
    new GetFamilyUseCase({
      repository: repository as unknown as FamilyProfileRepositoryPort,
      transactionRunner: runner,
    });
  const update = () =>
    new UpdateFamilyUseCase({
      repository: repository as unknown as FamilyProfileRepositoryPort,
      transactionRunner: runner,
      clock: { now: () => new Date(), nowIsoString: () => '' },
    });

  it('allows a member of the same family to read, but denies Kids', async () => {
    repository.findActorRole.mockResolvedValue('member');
    await expect(get().execute({ ...TEST_ACTOR, role: 'member' })).resolves.toEqual(family);
    await expect(get().execute({ ...TEST_ACTOR, role: 'kids' })).rejects.toBeInstanceOf(
      ActionNotAllowedError,
    );
    expect(repository.findFamily).toHaveBeenCalledWith(tx, TEST_ACTOR.familyId);
  });

  it('does not write for an omitted or unchanged name', async () => {
    await expect(update().execute(TEST_ACTOR, undefined)).resolves.toEqual(family);
    await expect(update().execute(TEST_ACTOR, 'Casa Silva')).resolves.toEqual(family);
    expect(repository.updateName).not.toHaveBeenCalled();
  });

  it('revalidates administrator access after the family lock', async () => {
    repository.findActorRole.mockResolvedValue('member');
    await expect(update().execute(TEST_ACTOR, 'Nova Casa')).rejects.toBeInstanceOf(
      ActionNotAllowedError,
    );
    expect(repository.updateName).not.toHaveBeenCalled();
  });

  it('validates and persists only the changed name', async () => {
    await expect(update().execute(TEST_ACTOR, '  Nova Casa  ')).resolves.toEqual({
      ...family,
      name: 'Nova Casa',
    });
    expect(repository.updateName).toHaveBeenCalledWith(
      tx,
      TEST_ACTOR.familyId,
      'Nova Casa',
      expect.any(Date),
    );
    await expect(update().execute(TEST_ACTOR, '  ')).rejects.toBeInstanceOf(ValidationError);
  });
});
