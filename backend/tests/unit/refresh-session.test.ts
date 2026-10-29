/**
 * Caso de uso `RefreshSession` — CA-08.
 *
 * Cobre a exigência da prova de instalação, a janela de 15 minutos do novo
 * token e a preservação dos access tokens anteriores ainda válidos.
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { RefreshSessionUseCase } from '../../src/modules/access/application/refresh-session-use-case.js';
import { SessionRevokedError } from '../../src/modules/access/domain/access-errors.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import {
  createFakeCrypto,
  InMemoryAccessRepository,
  seedActiveSession,
  sha256Hex,
} from './support/access-doubles.js';

const FIXED_NOW = new Date('2026-10-08T12:00:00.000Z');
const IN_TEN_MINUTES = new Date(FIXED_NOW.getTime() + 10 * 60 * 1000);
const FIFTEEN_MINUTES_MS = 15 * 60 * 1000;

describe('RefreshSession use case (CA-08)', () => {
  let repository: InMemoryAccessRepository;
  let crypto: ReturnType<typeof createFakeCrypto>;
  let useCase: RefreshSessionUseCase;
  let transactionContext: TransactionContext;
  let runCallCount: number;

  beforeEach(() => {
    repository = new InMemoryAccessRepository();
    crypto = createFakeCrypto();
    runCallCount = 0;
    transactionContext = { client: { marker: 'single-transaction' } };

    const transactionRunner: TransactionRunner = {
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

    useCase = new RefreshSessionUseCase({ repository, crypto, transactionRunner, clock });
  });

  function givenActiveSession() {
    return seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });
  }

  describe('renovação com prova de instalação válida', () => {
    it('issues a new access token valid for 15 minutes', async () => {
      const seeded = givenActiveSession();

      const result = await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(result.accessToken).toBe(crypto.issuedTokens[0]);
      expect(result.accessTokenExpiresAt).toBe(
        new Date(FIXED_NOW.getTime() + FIFTEEN_MINUTES_MS).toISOString(),
      );
    });

    it('persists only the hash of the new access token', async () => {
      const seeded = givenActiveSession();

      const result = await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(repository.insertedAccessTokens).toHaveLength(1);
      expect(repository.insertedAccessTokens[0]?.tokenHash).toBe(sha256Hex(result.accessToken));
      expect(repository.insertedAccessTokens[0]?.sessionId).toBe(seeded.sessionId);
    });

    it('keeps the previous access token valid inside its own 15 minute window', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      const previous = repository.accessTokens.find(
        (token) => token.tokenHash === sha256Hex(seeded.accessToken),
      );
      expect(previous?.revokedAt).toBeUndefined();
      expect(repository.accessTokens).toHaveLength(2);
      expect(repository.operations).not.toContain('revokeAccessTokensForSession');
    });

    it('does not reissue or revoke the refresh token', async () => {
      const seeded = givenActiveSession();

      const result = await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(result).not.toHaveProperty('refreshToken');
      expect(repository.sessions[0]?.refreshTokenHash).toBe(sha256Hex(seeded.refreshToken));
      expect(repository.sessions[0]?.revokedAt).toBeUndefined();
    });

    it('marks the session as seen in the same transaction as the insert', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(repository.sessions[0]?.lastSeenAt).toBeInstanceOf(Date);
      expect(runCallCount).toBe(1);
      expect(repository.seenContexts.every((context) => context === transactionContext)).toBe(true);
      expect(repository.operations).toEqual([
        'findSessionByRefreshToken',
        'insertAccessToken',
        'touchSessionLastSeen',
      ]);
    });

    it('does not revoke the session or its member', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(repository.operations).not.toContain('revokeSessionById');
      expect(repository.members).toHaveLength(1);
    });
  });

  describe('rejeição com SESSION_REVOKED', () => {
    it('rejects an unknown refresh token', async () => {
      await expect(
        useCase.execute({ refreshToken: 'never-issued', installationProof: 'any-proof' }),
      ).rejects.toThrow(SessionRevokedError);
    });

    it('rejects a refresh token of a revoked session', async () => {
      const seeded = givenActiveSession();
      const session = repository.sessions[0];
      if (session === undefined) {
        throw new Error('expected a seeded session');
      }
      session.revokedAt = FIXED_NOW;

      await expect(
        useCase.execute({
          refreshToken: seeded.refreshToken,
          installationProof: seeded.installationProof,
        }),
      ).rejects.toThrow(SessionRevokedError);
    });

    it('rejects a refresh token presented with a different installation proof', async () => {
      const seeded = givenActiveSession();

      await expect(
        useCase.execute({
          refreshToken: seeded.refreshToken,
          installationProof: 'proof-from-another-installation',
        }),
      ).rejects.toThrow(SessionRevokedError);
    });

    it('issues nothing when the installation proof diverges', async () => {
      const seeded = givenActiveSession();

      await expect(
        useCase.execute({
          refreshToken: seeded.refreshToken,
          installationProof: 'proof-from-another-installation',
        }),
      ).rejects.toThrow(SessionRevokedError);

      expect(repository.insertedAccessTokens).toHaveLength(0);
      expect(repository.sessions[0]?.lastSeenAt).toBeUndefined();
    });

    it('compares the installation proof through the constant-time hash check', async () => {
      const seeded = givenActiveSession();
      const comparisons: string[][] = [];
      crypto.hashesMatch = (left: string, right: string) => {
        comparisons.push([left, right]);
        return left === right;
      };

      await useCase.execute({
        refreshToken: seeded.refreshToken,
        installationProof: seeded.installationProof,
      });

      expect(comparisons).toEqual([
        [sha256Hex(seeded.installationProof), sha256Hex(seeded.installationProof)],
      ]);
      expect(comparisons[0]?.[0]).not.toContain(seeded.installationProof);
    });

    it('does not echo the submitted credentials in the error message', async () => {
      const seeded = givenActiveSession();

      await expect(
        useCase.execute({
          refreshToken: seeded.refreshToken,
          installationProof: 'proof-from-another-installation',
        }),
      ).rejects.toThrow(/^The session has been revoked\.$/);
    });
  });
});
