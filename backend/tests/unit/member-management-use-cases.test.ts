import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CreateMemberUseCase,
  ChangeMemberRoleUseCase,
  GetMemberDetailUseCase,
  LeaveAdministrationUseCase,
  ListFamilyMembersUseCase,
  MEMBERS_PAGE_SIZE,
  RemoveMemberUseCase,
  UpdateMemberUseCase,
} from '../../src/modules/family/application/member-management-use-cases.js';
import type {
  MemberManagementRepositoryPort,
  MemberRecord,
} from '../../src/modules/family/application/member-management-repository-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import { ActionNotAllowedError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const NOW = new Date('2026-10-08T15:00:00.000Z');
const OTHER_FAMILY_ID = '22222222-3333-4444-5555-666677778888';

function member(id: string, createdAt = NOW): MemberRecord {
  return {
    id,
    name: `Member ${id}`,
    role: MemberRole.MEMBER,
    isFamilyCreator: false,
    createdAt,
  };
}

describe('Member management use cases — SPEC-003 phase 1', () => {
  let repository: Record<keyof MemberManagementRepositoryPort, ReturnType<typeof vi.fn>>;
  let transactionRunner: TransactionRunner;

  beforeEach(() => {
    repository = {
      findMembersPage: vi.fn(),
      findMember: vi.fn(),
      findMemberRole: vi.fn().mockResolvedValue(MemberRole.ADMINISTRATOR),
      insertMember: vi.fn().mockImplementation(async (_tx, input) => ({
        id: input.id,
        name: input.name,
        role: input.role,
        isFamilyCreator: false,
        createdAt: input.createdAt,
      })),
      updateMember: vi.fn(),
      removeMember: vi.fn(),
    };
    transactionRunner = {
      run: vi.fn(async (work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
      forFamily: vi.fn(async (_id: string, work: (tx: TransactionContext) => Promise<unknown>) =>
        work({ client: {} }),
      ),
    } as unknown as TransactionRunner;
  });

  const dependencies = () => ({
    repository: repository as unknown as MemberManagementRepositoryPort,
    transactionRunner,
  });
  const managementDependencies = () => ({
    ...dependencies(),
    clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
  });

  it('CA-01 creates a normalized member in the session family under the family lock', async () => {
    const result = await new CreateMemberUseCase({
      ...dependencies(),
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    }).execute({ actor: TEST_ACTOR, name: ' Marina Silva ', role: MemberRole.KIDS });

    expect(result).toMatchObject({ name: 'Marina Silva', role: MemberRole.KIDS });
    expect(transactionRunner.forFamily).toHaveBeenCalledWith(
      TEST_ACTOR.familyId,
      expect.any(Function),
    );
    expect(repository.findMemberRole).toHaveBeenCalledWith(expect.anything(), {
      familyId: TEST_ACTOR.familyId,
      memberId: TEST_ACTOR.memberId,
    });
    expect(repository.insertMember).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ familyId: TEST_ACTOR.familyId, name: 'Marina Silva' }),
    );
  });

  it.each([
    { name: '', role: MemberRole.MEMBER, error: { name: ['MEMBER_NAME_REQUIRED'] } },
    {
      name: 'Ana\nSilva',
      role: MemberRole.MEMBER,
      error: { name: ['MEMBER_NAME_INVALID_CONTENT'] },
    },
    { name: 'Ana', role: 'owner', error: { role: ['MEMBER_ROLE_INVALID'] } },
  ])('CA-02 rejects invalid member input', async ({ name, role, error }) => {
    const useCase = new CreateMemberUseCase({
      ...dependencies(),
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
    await expect(useCase.execute({ actor: TEST_ACTOR, name, role })).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: error,
    });
    expect(repository.insertMember).not.toHaveBeenCalled();
  });

  it('CA-03 denies a write after the persisted role changes while waiting for the lock', async () => {
    repository.findMemberRole.mockResolvedValue(MemberRole.MEMBER);
    const useCase = new CreateMemberUseCase({
      ...dependencies(),
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
    await expect(
      useCase.execute({ actor: TEST_ACTOR, name: 'Marina', role: MemberRole.MEMBER }),
    ).rejects.toBeInstanceOf(ActionNotAllowedError);
    expect(repository.insertMember).not.toHaveBeenCalled();
  });

  it('SPEC-003 CA-02/03 permits an administrator to correct only a Kids name', async () => {
    const target = member('11111111-2222-4333-8444-555555555555');
    const update = new UpdateMemberUseCase(managementDependencies());
    repository.findMember.mockResolvedValue({ ...target, role: MemberRole.MEMBER });
    await expect(update.execute(TEST_ACTOR, target.id, 'New name')).rejects.toBeInstanceOf(
      ActionNotAllowedError,
    );
    await expect(update.execute(TEST_ACTOR, target.id, '')).rejects.toBeInstanceOf(
      ActionNotAllowedError,
    );
    expect(repository.updateMember).not.toHaveBeenCalled();

    repository.findMember.mockResolvedValue({ ...target, role: MemberRole.KIDS });
    repository.updateMember.mockResolvedValue({
      ...target,
      name: 'New name',
      role: MemberRole.KIDS,
    });
    await expect(update.execute(TEST_ACTOR, target.id, ' New name ')).resolves.toMatchObject({
      name: 'New name',
      role: MemberRole.KIDS,
    });
    expect(repository.updateMember).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        memberId: target.id,
        name: 'New name',
      }),
    );
  });

  it('CA-07 reports an unavailable dependency without claiming the member was created', async () => {
    repository.insertMember.mockRejectedValue(new Error('database connection lost'));
    const useCase = new CreateMemberUseCase({
      ...dependencies(),
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
    });
    await expect(
      useCase.execute({ actor: TEST_ACTOR, name: 'Marina', role: MemberRole.MEMBER }),
    ).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', statusCode: 503 });
  });

  it('returns the first page with an opaque continuation cursor', async () => {
    const records = Array.from({ length: MEMBERS_PAGE_SIZE + 1 }, (_, index) =>
      member(`00000000-0000-4000-8000-${String(index).padStart(12, '0')}`, NOW),
    );
    repository.findMembersPage.mockResolvedValue(records);

    const result = await new ListFamilyMembersUseCase(dependencies()).execute(
      TEST_ACTOR,
      undefined,
    );

    expect(result.items).toHaveLength(MEMBERS_PAGE_SIZE);
    expect(result.nextCursor).toEqual(expect.any(String));
    expect(repository.findMembersPage).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ familyId: TEST_ACTOR.familyId, limit: MEMBERS_PAGE_SIZE + 1 }),
    );
  });

  it('rejects a malformed cursor before querying persistence', async () => {
    await expect(
      new ListFamilyMembersUseCase(dependencies()).execute(TEST_ACTOR, 'not-a-member-cursor'),
    ).rejects.toMatchObject({
      code: 'VALIDATION_FAILED',
      fieldErrors: { cursor: ['CURSOR_INVALID'] },
    });
    expect(repository.findMembersPage).not.toHaveBeenCalled();
  });

  it('CA-03 rejects Kids and hides another family member through the scoped repository', async () => {
    const list = new ListFamilyMembersUseCase(dependencies());
    await expect(
      list.execute({ ...TEST_ACTOR, role: MemberRole.KIDS }, undefined),
    ).rejects.toBeInstanceOf(ActionNotAllowedError);

    repository.findMember.mockResolvedValue(undefined);
    await expect(
      new GetMemberDetailUseCase(dependencies()).execute(TEST_ACTOR, `${OTHER_FAMILY_ID}-member`),
    ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
  });

  it('lets an adult consult a detail and exposes only the actor capability', async () => {
    repository.findMember.mockResolvedValue(member('11111111-2222-4333-8444-555555555555'));
    const result = await new GetMemberDetailUseCase(dependencies()).execute(
      { ...TEST_ACTOR, role: MemberRole.MEMBER },
      '11111111-2222-4333-8444-555555555555',
    );
    expect(result.capabilities).toEqual({ manageMembers: false });
  });

  it('SPEC-003 CA-04 protects the creator and refuses direct Kids promotion', async () => {
    const target = member('11111111-2222-4333-8444-555555555555');
    repository.findMember.mockResolvedValue({ ...target, isFamilyCreator: true });
    const change = new ChangeMemberRoleUseCase(managementDependencies());
    await expect(change.execute(TEST_ACTOR, target.id, MemberRole.MEMBER)).rejects.toMatchObject({
      code: 'MEMBER_STATE_CONFLICT',
    });
    repository.findMember.mockResolvedValue({ ...target, role: MemberRole.KIDS });
    await expect(
      change.execute(TEST_ACTOR, target.id, MemberRole.ADMINISTRATOR),
    ).rejects.toMatchObject({
      code: 'MEMBER_STATE_CONFLICT',
    });
    expect(repository.updateMember).not.toHaveBeenCalled();
  });

  it('SPEC-003 CA-05 allows only a non-creator Admin to leave administration', async () => {
    const own = { ...member(TEST_ACTOR.memberId), role: MemberRole.ADMINISTRATOR };
    repository.findMember.mockResolvedValue({ ...own, isFamilyCreator: true });
    const leave = new LeaveAdministrationUseCase(managementDependencies());
    await expect(leave.execute(TEST_ACTOR)).rejects.toMatchObject({
      code: 'MEMBER_STATE_CONFLICT',
    });
    repository.findMember.mockResolvedValue(own);
    repository.updateMember.mockResolvedValue({ ...own, role: MemberRole.MEMBER });
    expect((await leave.execute({ ...TEST_ACTOR, isFamilyCreator: false })).role).toBe(
      MemberRole.MEMBER,
    );
    expect(repository.updateMember).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        memberId: TEST_ACTOR.memberId,
        role: MemberRole.MEMBER,
      }),
    );
  });

  it('SPEC-003 CA-06 revalidates Admin role before member removal', async () => {
    const target = member('11111111-2222-4333-8444-555555555555');
    repository.findMember.mockResolvedValue(target);
    repository.findMemberRole.mockResolvedValue(MemberRole.MEMBER);
    const remove = new RemoveMemberUseCase(managementDependencies());
    await expect(remove.execute(TEST_ACTOR, target.id)).rejects.toBeInstanceOf(
      ActionNotAllowedError,
    );
    expect(repository.removeMember).not.toHaveBeenCalled();
    repository.findMemberRole.mockResolvedValue(MemberRole.ADMINISTRATOR);
    await remove.execute(TEST_ACTOR, target.id);
    expect(repository.removeMember).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        familyId: TEST_ACTOR.familyId,
        memberId: target.id,
      }),
    );
  });
});
