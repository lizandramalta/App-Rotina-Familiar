/**
 * Casos de uso de exclusão de conta — SPEC-022 CA-01, CA-05–CA-07, CA-10–CA-13,
 * CA-16–CA-19. A persistência é um dublê em memória: o que está sob teste é a
 * autorização, a escolha do alvo e a orquestração com a Apple e a fila.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DeleteOwnAccountUseCase } from '../../src/modules/account/application/delete-own-account-use-case.js';
import { DeleteKidsAccountUseCase } from '../../src/modules/account/application/delete-kids-account-use-case.js';
import type {
  AccountDeletionRepositoryPort,
  CreatorAppleCredentials,
  DeletableMemberRecord,
} from '../../src/modules/account/application/account-deletion-ports.js';
import { AppleProofRequiredError } from '../../src/modules/account/domain/account-errors.js';
import {
  AppleProofInvalidError,
  SessionRevokedError,
} from '../../src/modules/access/domain/access-errors.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  NotFoundError,
} from '../../src/shared/domain/domain-error.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { AppleTokenVerifierPort } from '../../src/integrations/apple/apple-token-verifier-port.js';
import type { TransactionRunner } from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { createSilentLogger, sha256Hex } from './support/access-doubles.js';

const NOW = new Date('2026-11-17T12:00:00.000Z');
const FAMILY_ID = '11112222-3333-4444-5555-666677778888';
const CREATOR_ID = 'aaaa0000-0000-4000-8000-000000000001';
const ADULT_ID = 'aaaa0000-0000-4000-8000-000000000002';
const KIDS_ID = 'aaaa0000-0000-4000-8000-000000000003';
const ADMIN_ID = 'aaaa0000-0000-4000-8000-000000000004';
const APPLE_SUBJECT = '001234.subject';
const PROOF = { identityToken: 'jwt', authorizationCode: 'code', rawNonce: 'nonce' };

function actor(memberId: string, role: MemberRole, isFamilyCreator = false): ActorContext {
  return { sessionId: 'session', familyId: FAMILY_ID, memberId, role, isFamilyCreator };
}

class InMemoryAccountDeletionRepository implements AccountDeletionRepositoryPort {
  public members = new Map<string, DeletableMemberRecord>();
  public credentials: CreatorAppleCredentials | undefined;
  public deletedMembers: string[] = [];
  public deletedFamilies: { familyId: string; creatorIdentityId: string }[] = [];
  public revocations: { id: string; tokenEncrypted: string; tokenTypeHint: string }[] = [];
  public operations: string[] = [];

  async findActiveMember(_tx: unknown, params: { familyId: string; memberId: string }) {
    return params.familyId === FAMILY_ID ? this.members.get(params.memberId) : undefined;
  }

  async findCreatorAppleCredentials() {
    return this.credentials;
  }

  async deleteMemberAccount(_tx: unknown, params: { memberId: string }) {
    this.operations.push('deleteMemberAccount');
    this.deletedMembers.push(params.memberId);
    this.members.delete(params.memberId);
  }

  async deleteFamily(_tx: unknown, params: { familyId: string; creatorIdentityId: string }) {
    this.operations.push('deleteFamily');
    this.deletedFamilies.push(params);
    return { memberCount: this.members.size };
  }

  async enqueueAppleTokenRevocation(
    _tx: unknown,
    params: { id: string; tokenEncrypted: string; tokenTypeHint: string },
  ) {
    this.operations.push('enqueueAppleTokenRevocation');
    this.revocations.push({
      id: params.id,
      tokenEncrypted: params.tokenEncrypted,
      tokenTypeHint: params.tokenTypeHint,
    });
  }
}

describe('Account deletion use cases (SPEC-022)', () => {
  let repository: InMemoryAccountDeletionRepository;
  let verifyIdentityProof: ReturnType<typeof vi.fn>;
  let processNow: ReturnType<typeof vi.fn>;
  let transactionRunner: TransactionRunner;
  let lockedFamilies: string[];
  let ownAccount: DeleteOwnAccountUseCase;
  let kidsAccount: DeleteKidsAccountUseCase;

  beforeEach(() => {
    repository = new InMemoryAccountDeletionRepository();
    repository.members.set(CREATOR_ID, {
      id: CREATOR_ID,
      role: MemberRole.ADMINISTRATOR,
      isFamilyCreator: true,
    });
    repository.members.set(ADULT_ID, {
      id: ADULT_ID,
      role: MemberRole.MEMBER,
      isFamilyCreator: false,
    });
    repository.members.set(KIDS_ID, { id: KIDS_ID, role: MemberRole.KIDS, isFamilyCreator: false });
    repository.members.set(ADMIN_ID, {
      id: ADMIN_ID,
      role: MemberRole.ADMINISTRATOR,
      isFamilyCreator: false,
    });
    repository.credentials = {
      creatorIdentityId: 'identity-1',
      appleSubjectHash: sha256Hex(APPLE_SUBJECT),
      refreshTokenEncrypted: 'cipher(stored-refresh)',
    };
    verifyIdentityProof = vi
      .fn()
      .mockResolvedValue({ subject: APPLE_SUBJECT, refreshToken: 'fresh-refresh' });
    processNow = vi.fn().mockResolvedValue(undefined);
    lockedFamilies = [];
    transactionRunner = {
      run: async (work) => work({ client: {} }),
      forFamily: async (familyId, work) => {
        lockedFamilies.push(familyId);
        return work({ client: {} });
      },
    };
    let idCounter = 0;
    const deps = {
      repository,
      transactionRunner,
      clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
      logger: createSilentLogger(),
    };
    ownAccount = new DeleteOwnAccountUseCase({
      ...deps,
      tokenVerifier: { verifyIdentityProof } as unknown as AppleTokenVerifierPort,
      crypto: {
        newId: () => `revocation-${++idCounter}`,
        hashAppleSubject: sha256Hex,
        hashesMatch: (left, right) => left === right,
      },
      secretCipher: { encrypt: (value) => `cipher(${value})`, decrypt: (value) => value },
      appleTokenRevoker: { processNow: processNow as unknown as (id: string) => Promise<void> },
    });
    kidsAccount = new DeleteKidsAccountUseCase(deps);
  });

  describe('non-creator self deletion', () => {
    it('CA-01 deletes only the session holder under the family lock', async () => {
      await ownAccount.execute(actor(ADULT_ID, MemberRole.MEMBER));

      expect(repository.deletedMembers).toEqual([ADULT_ID]);
      expect(lockedFamilies).toEqual([FAMILY_ID]);
      expect(repository.deletedFamilies).toEqual([]);
      expect(verifyIdentityProof).not.toHaveBeenCalled();
    });

    it('CA-05 lets a Kids profile delete its own account', async () => {
      await ownAccount.execute(actor(KIDS_ID, MemberRole.KIDS));

      expect(repository.deletedMembers).toEqual([KIDS_ID]);
    });

    it('ignores an Apple proof sent by a non-creator', async () => {
      await ownAccount.execute(actor(ADULT_ID, MemberRole.MEMBER), { apple: PROOF });

      expect(verifyIdentityProof).not.toHaveBeenCalled();
      expect(repository.revocations).toEqual([]);
    });

    it('CA-07/CA-19 answers SESSION_REVOKED when the profile was removed while waiting for the lock', async () => {
      repository.members.delete(ADULT_ID);

      await expect(ownAccount.execute(actor(ADULT_ID, MemberRole.MEMBER))).rejects.toBeInstanceOf(
        SessionRevokedError,
      );
      expect(repository.deletedMembers).toEqual([]);
    });

    it('translates an unexpected persistence failure into DEPENDENCY_UNAVAILABLE', async () => {
      repository.deleteMemberAccount = vi.fn().mockRejectedValue(new Error('connection reset'));

      await expect(ownAccount.execute(actor(ADULT_ID, MemberRole.MEMBER))).rejects.toBeInstanceOf(
        DependencyUnavailableError,
      );
    });
  });

  describe('creator deletion', () => {
    const creator = () => actor(CREATOR_ID, MemberRole.ADMINISTRATOR, true);

    it('CA-12/CA-13 uses the stored token, enqueues it in the same transaction and tries it after commit', async () => {
      await ownAccount.execute(creator());

      expect(repository.operations).toEqual(['enqueueAppleTokenRevocation', 'deleteFamily']);
      expect(repository.revocations).toEqual([
        {
          id: 'revocation-1',
          tokenEncrypted: 'cipher(stored-refresh)',
          tokenTypeHint: 'refresh_token',
        },
      ]);
      expect(repository.deletedFamilies).toEqual([
        { familyId: FAMILY_ID, creatorIdentityId: 'identity-1' },
      ]);
      expect(processNow).toHaveBeenCalledWith('revocation-1');
      expect(verifyIdentityProof).not.toHaveBeenCalled();
    });

    it('CA-10 requires an Apple proof when no token is stored', async () => {
      repository.credentials = { ...repository.credentials!, refreshTokenEncrypted: undefined };

      await expect(ownAccount.execute(creator())).rejects.toBeInstanceOf(AppleProofRequiredError);
      expect(repository.deletedFamilies).toEqual([]);
    });

    it('accepts a fresh Apple proof and revokes the refresh token obtained from it', async () => {
      repository.credentials = { ...repository.credentials!, refreshTokenEncrypted: undefined };

      await ownAccount.execute(creator(), { apple: PROOF });

      expect(verifyIdentityProof).toHaveBeenCalledWith(PROOF);
      expect(repository.revocations[0]).toMatchObject({
        tokenEncrypted: 'cipher(fresh-refresh)',
        tokenTypeHint: 'refresh_token',
      });
    });

    it('falls back to the Apple access token when the proof returns no refresh token', async () => {
      repository.credentials = { ...repository.credentials!, refreshTokenEncrypted: undefined };
      verifyIdentityProof.mockResolvedValue({
        subject: APPLE_SUBJECT,
        accessToken: 'fresh-access',
      });

      await ownAccount.execute(creator(), { apple: PROOF });

      expect(repository.revocations[0]).toMatchObject({
        tokenEncrypted: 'cipher(fresh-access)',
        tokenTypeHint: 'access_token',
      });
    });

    it('CA-11 rejects a proof of another Apple identity without deleting anything', async () => {
      verifyIdentityProof.mockResolvedValue({ subject: 'another-subject', refreshToken: 'x' });

      await expect(ownAccount.execute(creator(), { apple: PROOF })).rejects.toBeInstanceOf(
        AppleProofInvalidError,
      );
      expect(repository.deletedFamilies).toEqual([]);
      expect(repository.revocations).toEqual([]);
    });

    it('CA-11 rejects a proof refused by the verifier (nonce, signature or code exchange)', async () => {
      verifyIdentityProof.mockRejectedValue(new Error('raw_nonce_mismatch'));

      await expect(ownAccount.execute(creator(), { apple: PROOF })).rejects.toBeInstanceOf(
        AppleProofInvalidError,
      );
      expect(repository.deletedFamilies).toEqual([]);
    });

    it('CA-13 keeps the deletion when the immediate revocation attempt fails', async () => {
      processNow.mockResolvedValue(undefined);

      await expect(ownAccount.execute(creator())).resolves.toBeUndefined();
      expect(repository.deletedFamilies).toHaveLength(1);
    });

    it('answers SESSION_REVOKED when the creator identity is no longer found', async () => {
      repository.credentials = undefined;

      await expect(ownAccount.execute(creator())).rejects.toBeInstanceOf(SessionRevokedError);
    });
  });

  describe('administrator deleting a Kids account', () => {
    it('CA-16 deletes the Kids account of the same family', async () => {
      await kidsAccount.execute(actor(ADMIN_ID, MemberRole.ADMINISTRATOR), KIDS_ID);

      expect(repository.deletedMembers).toEqual([KIDS_ID]);
      expect(lockedFamilies).toEqual([FAMILY_ID]);
    });

    it('CA-17 refuses Members and Kids actors', async () => {
      await expect(
        kidsAccount.execute(actor(ADULT_ID, MemberRole.MEMBER), KIDS_ID),
      ).rejects.toBeInstanceOf(ActionNotAllowedError);
      await expect(
        kidsAccount.execute(actor(KIDS_ID, MemberRole.KIDS), KIDS_ID),
      ).rejects.toBeInstanceOf(ActionNotAllowedError);
      expect(repository.deletedMembers).toEqual([]);
    });

    it('CA-17 refuses an adult target', async () => {
      await expect(
        kidsAccount.execute(actor(ADMIN_ID, MemberRole.ADMINISTRATOR), ADULT_ID),
      ).rejects.toBeInstanceOf(ActionNotAllowedError);
      expect(repository.deletedMembers).toEqual([]);
    });

    it('CA-17 revalidates the persisted role of a stale administrator session', async () => {
      repository.members.set(ADMIN_ID, {
        id: ADMIN_ID,
        role: MemberRole.MEMBER,
        isFamilyCreator: false,
      });

      await expect(
        kidsAccount.execute(actor(ADMIN_ID, MemberRole.ADMINISTRATOR), KIDS_ID),
      ).rejects.toBeInstanceOf(ActionNotAllowedError);
    });

    it('CA-18 answers RESOURCE_NOT_FOUND for a target outside the family or already deleted', async () => {
      await expect(
        kidsAccount.execute(
          actor(ADMIN_ID, MemberRole.ADMINISTRATOR),
          'ffff0000-0000-4000-8000-000000000009',
        ),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });
});
