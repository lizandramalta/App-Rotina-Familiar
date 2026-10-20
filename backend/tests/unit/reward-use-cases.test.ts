import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  AddRewardItemUseCase,
  ListRewardItemsUseCase,
} from '../../src/modules/rewards/application/reward-use-cases.js';
import type { RewardRepositoryPort } from '../../src/modules/rewards/application/reward-repository-port.js';
import { RewardTitleAlreadyExistsError } from '../../src/modules/rewards/domain/reward-errors.js';
import {
  validateRewardDetails,
  validateRewardTitle,
} from '../../src/modules/rewards/domain/reward-validation.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const NOW = new Date('2026-10-20T12:00:00.000Z');
const ITEM_ID = '1a1b1c1d-2222-4333-8444-555566667777';

describe('Reward items — SPEC-015 phase 1 / SCRUM-80', () => {
  let repository: Record<keyof RewardRepositoryPort, ReturnType<typeof vi.fn>>;
  let runner: TransactionRunner;
  let forFamily: ReturnType<typeof vi.fn>;
  const { logger, calls } = createRecordingLogger();

  beforeEach(() => {
    calls.length = 0;
    repository = {
      findActorRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      listItems: vi.fn().mockResolvedValue([]),
      insertCustom: vi.fn().mockImplementation(async (_tx, item) => ({
        id: ITEM_ID,
        title: item.title,
        details: item.details,
        source: 'custom',
        createdAt: item.createdAt,
      })),
    };
    forFamily = vi.fn(async (_familyId, work: (tx: TransactionContext) => Promise<unknown>) =>
      work({ client: {} }),
    );
    runner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily,
    } as unknown as TransactionRunner;
  });

  const deps = () => ({
    repository: repository as unknown as RewardRepositoryPort,
    transactionRunner: runner,
    logger,
  });
  const add = () =>
    new AddRewardItemUseCase({
      ...deps(),
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
  const list = () => new ListRewardItemsUseCase(deps());

  it('CA-02/CA-04 trims a valid title, retains details and serializes the insert by family', async () => {
    const result = await add().execute({
      actor: TEST_ACTOR,
      title: '  Noite de pizza  ',
      details: 'Escolher juntos',
    });

    expect(forFamily).toHaveBeenCalledWith(TEST_ACTOR.familyId, expect.any(Function));
    expect(repository.insertCustom).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        createdById: TEST_ACTOR.memberId,
        title: 'Noite de pizza',
        normalizedTitle: 'noite de pizza',
        details: 'Escolher juntos',
      }),
    );
    expect(result).toEqual({
      id: ITEM_ID,
      title: 'Noite de pizza',
      details: 'Escolher juntos',
      source: 'custom',
      createdAt: NOW.toISOString(),
    });
    expect(JSON.stringify(calls)).not.toContain('Escolher juntos');
  });

  it.each([
    ['', 'REWARD_TITLE_REQUIRED'],
    ['  ', 'REWARD_TITLE_REQUIRED'],
    ['bad\u0000title', 'REWARD_TITLE_CONTROL_CHARACTERS'],
    ['a'.repeat(61), 'REWARD_TITLE_TOO_LONG'],
  ])('CA-03 rejects title %j with %s before persistence', async (title, code) => {
    await expect(
      add().execute({ actor: TEST_ACTOR, title, details: undefined }),
    ).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { title: [code] },
    });
    expect(repository.insertCustom).not.toHaveBeenCalled();
  });

  it('CA-02/CA-03 counts non-space Unicode characters and all detail spaces', () => {
    expect(validateRewardTitle(`  ${'á '.repeat(60)}  `).title).toHaveLength(119);
    expect(validateRewardDetails(' '.repeat(255))).toHaveLength(255);
    expect(() => validateRewardDetails(' '.repeat(256))).toThrowError(
      expect.objectContaining({ fieldErrors: { details: ['REWARD_DETAILS_TOO_LONG'] } }),
    );
  });

  it.each([MemberRole.MEMBER, MemberRole.KIDS])(
    'CA-05 rejects %s for list and add',
    async (role) => {
      const actor = { ...TEST_ACTOR, role };
      await expect(list().execute(actor)).rejects.toMatchObject({
        code: 'INSUFFICIENT_PERMISSIONS',
        statusCode: 403,
      });
      await expect(
        add().execute({ actor, title: 'Pizza', details: undefined }),
      ).rejects.toMatchObject({ code: 'INSUFFICIENT_PERMISSIONS', statusCode: 403 });
      expect(repository.listItems).not.toHaveBeenCalled();
      expect(repository.insertCustom).not.toHaveBeenCalled();
    },
  );

  it('CA-05 rechecks the role and session inside the transaction', async () => {
    repository.findActorRole.mockResolvedValue(MemberRole.MEMBER);
    await expect(
      add().execute({ actor: TEST_ACTOR, title: 'Pizza', details: undefined }),
    ).rejects.toMatchObject({ code: 'INSUFFICIENT_PERMISSIONS' });
    expect(repository.insertCustom).not.toHaveBeenCalled();
    repository.findActorRole.mockResolvedValue(undefined);
    await expect(list().execute(TEST_ACTOR)).rejects.toMatchObject({ code: 'SESSION_REVOKED' });
  });

  it('CA-01/CA-06 lists both sources with only the session family as input', async () => {
    repository.listItems.mockResolvedValue([
      { id: ITEM_ID, title: 'Sugestão', details: null, source: 'predefined', createdAt: NOW },
      { id: ITEM_ID, title: 'Pizza', details: 'Juntos', source: 'custom', createdAt: NOW },
    ]);
    const result = await list().execute(TEST_ACTOR);
    expect(repository.listItems).toHaveBeenCalledWith(expect.anything(), TEST_ACTOR.familyId);
    expect(result.predefined[0]).toEqual({
      id: ITEM_ID,
      title: 'Sugestão',
      details: null,
      source: 'predefined',
    });
    expect(result.custom[0]).toMatchObject({
      title: 'Pizza',
      source: 'custom',
      createdAt: NOW.toISOString(),
    });
  });

  it('CA-01 maps a list dependency failure to a safe 503 and records an aggregate outcome', async () => {
    repository.listItems.mockRejectedValue(new Error('SQL query detail must stay private'));
    await expect(list().execute(TEST_ACTOR)).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
      statusCode: 503,
    });
    expect(JSON.stringify(calls)).toContain('DEPENDENCY_UNAVAILABLE');
    expect(JSON.stringify(calls)).not.toContain('SQL query detail');
  });

  it('CA-04 records duplicate outcomes without logging the title or details', async () => {
    repository.insertCustom.mockRejectedValue(new RewardTitleAlreadyExistsError());
    await expect(
      add().execute({ actor: TEST_ACTOR, title: 'Private title', details: 'Private details' }),
    ).rejects.toMatchObject({ code: 'REWARD_TITLE_ALREADY_EXISTS' });
    expect(JSON.stringify(calls)).toContain('duplicate');
    expect(JSON.stringify(calls)).not.toContain('Private title');
    expect(JSON.stringify(calls)).not.toContain('Private details');
  });
});
