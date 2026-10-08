/**
 * Caso de uso `GetCurrentSession` — CA-07 e a consistência com CA-05.
 *
 * O repositório é dublê em memória: o que está sob teste é a projeção devolvida
 * e a escolha entre `SESSION_EXPIRED` e `SESSION_REVOKED`.
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { GetCurrentSessionUseCase } from '../../src/modules/access/application/get-current-session-use-case.js';
import {
  SessionExpiredError,
  SessionRevokedError,
} from '../../src/modules/access/domain/access-errors.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type { TransactionRunner } from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import {
  createFakeCrypto,
  InMemoryAccessRepository,
  seedActiveSession,
  sha256Hex,
} from './support/access-doubles.js';

const FIXED_NOW = new Date('2026-10-08T12:00:00.000Z');
const IN_TEN_MINUTES = new Date(FIXED_NOW.getTime() + 10 * 60 * 1000);

describe('GetCurrentSession use case (CA-07)', () => {
  let repository: InMemoryAccessRepository;
  let useCase: GetCurrentSessionUseCase;

  beforeEach(() => {
    repository = new InMemoryAccessRepository();

    const transactionRunner: TransactionRunner = {
      run: async (work) => work({ client: { marker: 'single-transaction' } }),
      forFamily: async (_familyId, work) => work({ client: { marker: 'single-transaction' } }),
    };

    const clock: Clock = {
      now: () => FIXED_NOW,
      nowIsoString: () => FIXED_NOW.toISOString(),
    };

    useCase = new GetCurrentSessionUseCase({
      repository,
      crypto: createFakeCrypto(),
      transactionRunner,
      clock,
    });
  });

  describe('sessão ativa', () => {
    it('returns the current member, family, role and creator flag', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: IN_TEN_MINUTES,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      });

      const result = await useCase.execute({ accessToken: seeded.accessToken });

      expect(result).toEqual({
        memberId: seeded.memberId,
        familyId: seeded.familyId,
        role: 'administrator',
        isFamilyCreator: true,
      });
    });

    it('reads the member state stored now, not the one captured at sign in', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: IN_TEN_MINUTES,
        role: MemberRole.ADMINISTRATOR,
      });

      repository.members = [
        {
          memberId: seeded.memberId,
          familyId: seeded.familyId,
          role: MemberRole.MEMBER,
          isFamilyCreator: false,
        },
      ];

      const result = await useCase.execute({ accessToken: seeded.accessToken });

      expect(result.role).toBe('member');
      expect(result.isFamilyCreator).toBe(false);
    });

    it('exposes no token, hash or secret in the result', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });

      const result = await useCase.execute({ accessToken: seeded.accessToken });

      expect(Object.keys(result).sort()).toEqual([
        'familyId',
        'isFamilyCreator',
        'memberId',
        'role',
      ]);
      const serialized = JSON.stringify(result);
      expect(serialized).not.toContain(seeded.accessToken);
      expect(serialized).not.toContain(seeded.refreshToken);
      expect(serialized).not.toContain(sha256Hex(seeded.accessToken));
    });

    it('looks the token up by its hash, never by the opaque value', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(repository.operations).toContain('findSessionByAccessToken');
      expect(repository.accessTokens[0]?.tokenHash).toBe(sha256Hex(seeded.accessToken));
    });
  });

  describe('token inválido ou expirado', () => {
    it('rejects an unknown access token with SESSION_EXPIRED', async () => {
      await expect(useCase.execute({ accessToken: 'never-issued' })).rejects.toThrow(
        SessionExpiredError,
      );
    });

    it('rejects a token already past its 15 minute window with SESSION_EXPIRED', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: new Date(FIXED_NOW.getTime() - 1000),
      });

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionExpiredError,
      );
    });

    it('rejects a token expiring exactly now with SESSION_EXPIRED', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: FIXED_NOW });

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionExpiredError,
      );
    });
  });

  describe('CA-05: sessão revogada', () => {
    it('rejects a token of a revoked session with SESSION_REVOKED', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });
      const session = repository.sessions[0];
      if (session === undefined) {
        throw new Error('expected a seeded session');
      }
      session.revokedAt = FIXED_NOW;
      session.revokedReason = 'explicit_sign_out';

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionRevokedError,
      );
    });

    it('prefers SESSION_REVOKED over SESSION_EXPIRED when both apply', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: new Date(FIXED_NOW.getTime() - 1000),
      });
      const session = repository.sessions[0];
      if (session === undefined) {
        throw new Error('expected a seeded session');
      }
      session.revokedAt = FIXED_NOW;

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionRevokedError,
      );
    });

    it('rejects an individually revoked access token with SESSION_REVOKED', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });
      const token = repository.accessTokens[0];
      if (token === undefined) {
        throw new Error('expected a seeded access token');
      }
      token.revokedAt = FIXED_NOW;

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionRevokedError,
      );
    });

    it('answers 401 on both rejection paths', async () => {
      expect(new SessionExpiredError().statusCode).toBe(401);
      expect(new SessionRevokedError().statusCode).toBe(401);
      expect(new SessionExpiredError().code).toBe('SESSION_EXPIRED');
      expect(new SessionRevokedError().code).toBe('SESSION_REVOKED');
    });

    it('never echoes the submitted token in the error message', async () => {
      const seeded = seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });
      const session = repository.sessions[0];
      if (session === undefined) {
        throw new Error('expected a seeded session');
      }
      session.revokedAt = FIXED_NOW;

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        /^The session has been revoked\.$/,
      );
    });
  });
});
