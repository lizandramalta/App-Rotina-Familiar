/**
 * Emissão de convite — SPEC-004 Fase 1 (CA-01 a CA-05 e CA-07), com dublês.
 * Concorrência (CA-06) e persistência real ficam em tests/integration.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  INVITE_REISSUED_REVOCATION_REASON,
  IssueMemberInviteUseCase,
} from '../../src/modules/family/application/issue-member-invite-use-case.js';
import type { MemberInviteRepositoryPort } from '../../src/modules/family/application/member-invite-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { CryptoInviteCredentials } from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';
import { TEST_ACTOR } from '../support/build-test-app.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const NOW = new Date('2026-10-09T15:00:00.000Z');
const TARGET_ID = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const COMMAND = { actor: TEST_ACTOR, memberId: TARGET_ID, requestId: 'req-1' };

describe('IssueMemberInviteUseCase — SPEC-004 phase 1', () => {
  let repository: Record<keyof MemberInviteRepositoryPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;
  let recording: ReturnType<typeof createRecordingLogger>;

  beforeEach(() => {
    repository = {
      findActorState: vi
        .fn()
        .mockResolvedValue({ role: MemberRole.ADMINISTRATOR, sessionActive: true }),
      findTarget: vi.fn().mockResolvedValue({ id: TARGET_ID, isFamilyCreator: false }),
      invalidateAvailableInvites: vi.fn().mockResolvedValue(undefined),
      revokeActiveSession: vi.fn().mockResolvedValue(undefined),
      insertInvite: vi.fn().mockResolvedValue(undefined),
    };
    transactionRunner = {
      run: vi.fn(),
      forFamily: vi.fn(async (_id: string, work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
    } as unknown as TransactionRunner;
    recording = createRecordingLogger();
  });

  const build = () =>
    new IssueMemberInviteUseCase({
      repository: repository as unknown as MemberInviteRepositoryPort,
      credentials: new CryptoInviteCredentials('https://app.example.test'),
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
      logger: recording.logger,
    });

  it('CA-01/CA-02/CA-05 invalidates, revokes and inserts under the family lock, persisting only protected verifiers', async () => {
    const result = await build().execute(COMMAND);

    expect(transactionRunner.forFamily).toHaveBeenCalledWith(
      TEST_ACTOR.familyId,
      expect.any(Function),
    );
    expect(repository.invalidateAvailableInvites).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TARGET_ID,
      at: NOW,
    });
    expect(repository.revokeActiveSession).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TARGET_ID,
      reason: INVITE_REISSUED_REVOCATION_REASON,
    });
    const inserted = repository.insertInvite.mock.calls[0]?.[1] as Record<string, unknown>;
    expect(inserted).toMatchObject({ id: result.inviteId, issuedByMemberId: TEST_ACTOR.memberId });

    const token = result.link.replace('https://app.example.test/invite/', '');
    expect(result.password).toMatch(/^[2-9A-HJ-NP-Z]{6}$/);
    expect(JSON.stringify(inserted)).not.toContain(token);
    expect(JSON.stringify(inserted)).not.toContain(result.password);
    expect(inserted.passwordVerifier).toMatch(/^scrypt\$v1\$/);
  });

  it('CA-01 issues brand-new credentials on every confirmed call', async () => {
    const first = await build().execute(COMMAND);
    const second = await build().execute(COMMAND);
    expect(second.link).not.toBe(first.link);
    expect(second.inviteId).not.toBe(first.inviteId);
  });

  it.each([MemberRole.MEMBER, MemberRole.KIDS])(
    'CA-03 refuses %s with ACTION_NOT_ALLOWED before touching the target',
    async (role) => {
      await expect(
        build().execute({ ...COMMAND, actor: { ...TEST_ACTOR, role } }),
      ).rejects.toMatchObject({
        code: 'ACTION_NOT_ALLOWED',
        statusCode: 403,
      });
      expect(repository.findTarget).not.toHaveBeenCalled();
      expect(repository.insertInvite).not.toHaveBeenCalled();
    },
  );

  it('CA-03 revalidates the persisted role after the lock (stale session)', async () => {
    repository.findActorState.mockResolvedValue({ role: MemberRole.MEMBER, sessionActive: true });
    await expect(build().execute(COMMAND)).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
    expect(repository.insertInvite).not.toHaveBeenCalled();
  });

  it('refuses when the actor session was revoked while waiting for the lock', async () => {
    repository.findActorState.mockResolvedValue({
      role: MemberRole.ADMINISTRATOR,
      sessionActive: false,
    });
    await expect(build().execute(COMMAND)).rejects.toMatchObject({ statusCode: 401 });
    expect(repository.insertInvite).not.toHaveBeenCalled();
  });

  it('CA-03 maps a target outside the actor family to RESOURCE_NOT_FOUND without writing', async () => {
    repository.findTarget.mockResolvedValue(undefined);
    await expect(build().execute(COMMAND)).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    expect(repository.revokeActiveSession).not.toHaveBeenCalled();
    expect(repository.insertInvite).not.toHaveBeenCalled();
  });

  it.each([
    ['the family creator', { id: TARGET_ID, isFamilyCreator: true }, TARGET_ID],
    [
      'the actor themself',
      { id: TEST_ACTOR.memberId, isFamilyCreator: false },
      TEST_ACTOR.memberId,
    ],
  ])('CA-04 refuses %s with INVITE_NOT_ISSUABLE', async (_label, target, memberId) => {
    repository.findTarget.mockResolvedValue(target);
    await expect(build().execute({ ...COMMAND, memberId })).rejects.toMatchObject({
      code: 'INVITE_NOT_ISSUABLE',
      statusCode: 409,
    });
    expect(repository.revokeActiveSession).not.toHaveBeenCalled();
    expect(repository.insertInvite).not.toHaveBeenCalled();
  });

  it('CA-07 reports an infrastructure failure as DEPENDENCY_UNAVAILABLE without claiming rollback', async () => {
    repository.insertInvite.mockRejectedValue(new Error('connection reset'));
    await expect(build().execute(COMMAND)).rejects.toMatchObject({
      code: 'DEPENDENCY_UNAVAILABLE',
      statusCode: 503,
    });
  });

  it('SPEC-004 §8 logs events with identifiers only — never a token, password, link or verifier', async () => {
    const issued = await build().execute(COMMAND);
    repository.insertInvite.mockRejectedValueOnce(new Error(`boom ${issued.password}`));
    await build()
      .execute(COMMAND)
      .catch(() => undefined);
    repository.findTarget.mockResolvedValueOnce(undefined);
    await build()
      .execute(COMMAND)
      .catch(() => undefined);

    const logged = JSON.stringify(recording.calls);
    expect(logged).toContain('member_invite_issued');
    expect(logged).toContain('member_invite_issue_denied');
    expect(logged).toContain('member_invite_issue_uncertain');
    const token = issued.link.split('/invite/')[1] ?? '';
    for (const secret of [token, issued.password, issued.link, 'scrypt$']) {
      expect(logged).not.toContain(secret);
    }
  });
});
