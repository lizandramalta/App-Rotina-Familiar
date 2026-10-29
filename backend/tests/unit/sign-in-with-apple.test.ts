/**
 * Caso de uso `SignInWithApple` — cobre CA-01 a CA-06 da SPEC-001 (Fase 1).
 *
 * A persistência e o verificador da Apple são dublês em memória: o que está sob
 * teste é a orquestração (vínculo, grant, sessão, revogação e isolamento).
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { SignInWithAppleUseCase } from '../../src/modules/access/application/sign-in-with-apple-use-case.js';
import { AppleProofInvalidError } from '../../src/modules/access/domain/access-errors.js';
import type { CreatorMembershipRecord } from '../../src/modules/access/application/access-repository-port.js';
import type { AppleTokenVerifierPort } from '../../src/integrations/apple/apple-token-verifier-port.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type { Logger } from '../../src/shared/infrastructure/observability/logger.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import {
  createFakeCrypto,
  createSilentLogger,
  InMemoryAccessRepository,
  sha256Hex,
} from './support/access-doubles.js';

const APPLE_SUBJECT = '001234.abcdef0123456789.0000';
const INSTALLATION_PROOF = 'installation-proof-opaque-value';
const FIXED_NOW = new Date('2026-10-08T12:00:00.000Z');

const VALID_COMMAND = {
  identityToken: 'valid-identity-token',
  authorizationCode: 'valid-authorization-code',
  rawNonce: 'valid-raw-nonce',
  installationProof: INSTALLATION_PROOF,
};

describe('SignInWithApple use case (SPEC-001 Fase 1)', () => {
  let repository: InMemoryAccessRepository;
  let crypto: ReturnType<typeof createFakeCrypto>;
  let logger: Logger;
  let verifyIdentityProof: ReturnType<typeof vi.fn>;
  let transactionRunner: TransactionRunner;
  let transactionContext: TransactionContext;
  let runCallCount: number;
  let useCase: SignInWithAppleUseCase;

  beforeEach(() => {
    repository = new InMemoryAccessRepository();
    crypto = createFakeCrypto();
    logger = createSilentLogger();
    runCallCount = 0;
    transactionContext = { client: { marker: 'single-transaction' } };

    verifyIdentityProof = vi.fn().mockResolvedValue({ subject: APPLE_SUBJECT });

    transactionRunner = {
      run: async (work) => {
        runCallCount += 1;
        return work(transactionContext);
      },
      forFamily: async (_familyId, work) => work(transactionContext),
    };

    const clock: Clock = {
      now: () => FIXED_NOW,
      nowIsoString: () => FIXED_NOW.toISOString(),
    };

    useCase = new SignInWithAppleUseCase({
      repository,
      tokenVerifier: { verifyIdentityProof } as unknown as AppleTokenVerifierPort,
      crypto,
      transactionRunner,
      clock,
      logger,
    });
  });

  function givenLinkedCreator(
    overrides: Partial<CreatorMembershipRecord> = {},
  ): CreatorMembershipRecord {
    repository.identities.push({ id: 'identity-1', appleSubjectHash: sha256Hex(APPLE_SUBJECT) });
    const membership: CreatorMembershipRecord = {
      memberId: 'member-persisted',
      familyId: 'family-persisted',
      role: MemberRole.ADMINISTRATOR,
      isFamilyCreator: true,
      ...overrides,
    };
    repository.membership = membership;
    return membership;
  }

  describe('CA-01: identidade com família vinculada', () => {
    it('opens the creator session with the persisted family and administrator role', async () => {
      givenLinkedCreator();

      const result = await useCase.execute(VALID_COMMAND);

      expect(result).toEqual({
        outcome: 'session',
        sessionId: expect.any(String),
        memberId: 'member-persisted',
        familyId: 'family-persisted',
        role: 'administrator',
        isFamilyCreator: true,
        accessToken: expect.any(String),
        accessTokenExpiresAt: '2026-10-08T12:15:00.000Z',
        refreshToken: expect.any(String),
      });
    });

    it('persists only hashes of the issued tokens, never the tokens themselves', async () => {
      givenLinkedCreator();

      const result = await useCase.execute(VALID_COMMAND);
      if (result.outcome !== 'session') {
        throw new Error('expected a session result');
      }

      const session = repository.insertedSessions[0];
      const accessToken = repository.insertedAccessTokens[0];

      expect(session?.refreshTokenHash).toBe(sha256Hex(result.refreshToken));
      expect(session?.installationProofHash).toBe(sha256Hex(INSTALLATION_PROOF));
      expect(accessToken?.tokenHash).toBe(sha256Hex(result.accessToken));

      const persisted = JSON.stringify([session, accessToken]);
      expect(persisted).not.toContain(result.accessToken);
      expect(persisted).not.toContain(result.refreshToken);
      expect(persisted).not.toContain(INSTALLATION_PROOF);
    });

    it('issues the access token with a 15 minute lifetime (BA-10)', async () => {
      givenLinkedCreator();

      await useCase.execute(VALID_COMMAND);

      expect(repository.insertedAccessTokens[0]?.expiresAt).toEqual(
        new Date('2026-10-08T12:15:00.000Z'),
      );
    });

    it('reuses the existing identity instead of inserting a duplicate', async () => {
      givenLinkedCreator();

      await useCase.execute(VALID_COMMAND);

      expect(repository.operations).not.toContain('insertIdentity');
      expect(repository.identities).toHaveLength(1);
    });
  });

  describe('CA-02: identidade sem família vinculada', () => {
    it('issues an opaque creation grant expiring in 10 minutes (BA-21)', async () => {
      const result = await useCase.execute(VALID_COMMAND);

      expect(result).toEqual({
        outcome: 'creationGrant',
        creationGrant: expect.any(String),
        expiresAt: '2026-10-08T12:10:00.000Z',
      });
    });

    it('persists the new Apple identity encrypted and hashed on first sign in', async () => {
      await useCase.execute(VALID_COMMAND);

      expect(repository.operations).toContain('insertIdentity');
      expect(repository.insertedGrants[0]?.creatorIdentityId).toBe(repository.identities[0]?.id);
      // O `sub` da Apple nunca é persistido em claro (SPEC-001 §5.1).
      expect(JSON.stringify(repository.identities)).not.toContain(APPLE_SUBJECT);
    });

    it('stores only the hash of the grant token', async () => {
      const result = await useCase.execute(VALID_COMMAND);
      if (result.outcome !== 'creationGrant') {
        throw new Error('expected a creation grant result');
      }

      const grant = repository.insertedGrants[0];
      expect(grant?.grantTokenHash).toBe(sha256Hex(result.creationGrant));
      expect(JSON.stringify(grant)).not.toContain(result.creationGrant);
    });

    it('does not open a session nor touch family data', async () => {
      await useCase.execute(VALID_COMMAND);

      expect(repository.insertedSessions).toHaveLength(0);
      expect(repository.insertedAccessTokens).toHaveLength(0);
      expect(repository.revokedWith).toHaveLength(0);
    });
  });

  describe('CA-04: prova Apple inválida', () => {
    it('rejects with APPLE_PROOF_INVALID and 401 when verification fails', async () => {
      verifyIdentityProof.mockRejectedValue(new Error('identity_token_signature_invalid'));

      await expect(useCase.execute(VALID_COMMAND)).rejects.toBeInstanceOf(AppleProofInvalidError);

      const error = await useCase.execute(VALID_COMMAND).catch((err: unknown) => err);
      expect((error as AppleProofInvalidError).code).toBe('APPLE_PROOF_INVALID');
      expect((error as AppleProofInvalidError).statusCode).toBe(401);
    });

    it('issues neither session nor grant when the proof is rejected', async () => {
      verifyIdentityProof.mockRejectedValue(new Error('identity_token_nonce_mismatch'));

      await expect(useCase.execute(VALID_COMMAND)).rejects.toBeInstanceOf(AppleProofInvalidError);

      expect(repository.insertedSessions).toHaveLength(0);
      expect(repository.insertedGrants).toHaveLength(0);
      expect(repository.identities).toHaveLength(0);
      expect(runCallCount).toBe(0);
    });

    it('does not leak the proof or the failure reason into the error message', async () => {
      verifyIdentityProof.mockRejectedValue(
        new Error(`nonce mismatch for ${VALID_COMMAND.rawNonce}`),
      );

      const error = await useCase.execute(VALID_COMMAND).catch((err: unknown) => err);

      expect((error as Error).message).not.toContain(VALID_COMMAND.rawNonce);
      expect((error as Error).message).not.toContain(VALID_COMMAND.identityToken);
    });

    it('never logs the Apple proof when reporting the rejection', async () => {
      verifyIdentityProof.mockRejectedValue(new Error('identity_token_expired'));

      await useCase.execute(VALID_COMMAND).catch(() => undefined);

      const logged = JSON.stringify((logger.warn as ReturnType<typeof vi.fn>).mock.calls);
      expect(logged).not.toContain(VALID_COMMAND.identityToken);
      expect(logged).not.toContain(VALID_COMMAND.authorizationCode);
      expect(logged).not.toContain(VALID_COMMAND.rawNonce);
      expect(logged).not.toContain(INSTALLATION_PROOF);
    });
  });

  describe('CA-04: authorizationCode conferido contra a Apple', () => {
    // Razões reais produzidas pelo AppleTokenVerifier no caminho da troca
    // server-to-server (ver apple-token-verifier.test.ts).
    it.each([
      'apple_token_exchange_rejected',
      'apple_token_exchange_unreachable',
      'authorization_code_subject_mismatch',
      'authorization_code_exchange_missing_subject',
      'apple_token_exchange_credentials_missing',
    ])('maps %s to 401 APPLE_PROOF_INVALID without issuing anything', async (reason) => {
      verifyIdentityProof.mockRejectedValue(new Error(reason));

      const error = await useCase.execute(VALID_COMMAND).catch((err: unknown) => err);

      expect(error).toBeInstanceOf(AppleProofInvalidError);
      expect((error as AppleProofInvalidError).statusCode).toBe(401);
      expect(repository.insertedSessions).toHaveLength(0);
      expect(repository.insertedGrants).toHaveLength(0);
      expect(repository.identities).toHaveLength(0);
    });

    it('does not reveal the exchange failure reason to the caller', async () => {
      verifyIdentityProof.mockRejectedValue(new Error('authorization_code_subject_mismatch'));

      const error = await useCase.execute(VALID_COMMAND).catch((err: unknown) => err);

      expect((error as Error).message).not.toContain('subject_mismatch');
    });

    it('forwards the authorizationCode to the verifier so it can be exchanged', async () => {
      givenLinkedCreator();

      await useCase.execute(VALID_COMMAND);

      expect(verifyIdentityProof).toHaveBeenCalledWith({
        identityToken: VALID_COMMAND.identityToken,
        authorizationCode: VALID_COMMAND.authorizationCode,
        rawNonce: VALID_COMMAND.rawNonce,
      });
    });
  });

  describe('CA-05: substituição da sessão anterior', () => {
    it('revokes the previous active session before inserting the new one', async () => {
      givenLinkedCreator();
      repository.activeSessionIds = ['previous-session'];

      await useCase.execute(VALID_COMMAND);

      expect(repository.revokedWith).toEqual([
        { memberId: 'member-persisted', reason: 'replaced_by_new_apple_sign_in' },
      ]);
      expect(repository.operations.indexOf('revokeSessions')).toBeLessThan(
        repository.operations.indexOf('insertSession'),
      );
    });

    it('runs the revocation and the new session in a single transaction', async () => {
      givenLinkedCreator();
      repository.activeSessionIds = ['previous-session'];

      await useCase.execute(VALID_COMMAND);

      expect(runCallCount).toBe(1);
      expect(new Set(repository.seenContexts)).toEqual(new Set([transactionContext]));
    });

    it('still opens a session when there is no previous one to revoke', async () => {
      givenLinkedCreator();
      repository.activeSessionIds = [];

      const result = await useCase.execute(VALID_COMMAND);

      expect(result.outcome).toBe('session');
      expect(repository.insertedSessions).toHaveLength(1);
    });

    it('propagates a persistence failure so the transaction rolls back', async () => {
      givenLinkedCreator();
      vi.spyOn(repository, 'insertSession').mockRejectedValue(new Error('unique violation'));

      await expect(useCase.execute(VALID_COMMAND)).rejects.toThrow('unique violation');
    });
  });

  describe('CA-06: isolamento multitenant', () => {
    it('derives familyId from the persisted link, ignoring any client supplied value', async () => {
      givenLinkedCreator({ familyId: 'family-from-database' });

      const result = await useCase.execute({
        ...VALID_COMMAND,
        // Um cliente malicioso enviaria isto; o comando não tem onde carregá-lo.
        ...({ familyId: 'family-forged-by-client' } as Record<string, unknown>),
      });

      if (result.outcome !== 'session') {
        throw new Error('expected a session result');
      }

      expect(result.familyId).toBe('family-from-database');
      expect(repository.insertedSessions[0]?.familyId).toBe('family-from-database');
    });

    it('scopes the session to the member and family returned by the repository', async () => {
      givenLinkedCreator({ memberId: 'member-xyz', familyId: 'family-xyz' });

      await useCase.execute(VALID_COMMAND);

      expect(repository.insertedSessions[0]).toMatchObject({
        memberId: 'member-xyz',
        familyId: 'family-xyz',
      });
    });

    it('reports the role persisted for the member instead of assuming administrator', async () => {
      givenLinkedCreator({ role: MemberRole.MEMBER, isFamilyCreator: false });

      const result = await useCase.execute(VALID_COMMAND);
      if (result.outcome !== 'session') {
        throw new Error('expected a session result');
      }

      expect(result.role).toBe('member');
      expect(result.isFamilyCreator).toBe(false);
    });
  });
});
