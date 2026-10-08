/**
 * Caso de uso `RevokeSession` — CA-09 e a consistência com CA-05.
 *
 * Cobre o encerramento atômico de sessão e access tokens, o log de segurança
 * `session_revoked` e a permanência do membro na família.
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { RevokeSessionUseCase } from '../../src/modules/access/application/revoke-session-use-case.js';
import {
  SessionExpiredError,
  SessionRevokedError,
} from '../../src/modules/access/domain/access-errors.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import type { Logger } from '../../src/shared/infrastructure/observability/logger.js';
import {
  createFakeCrypto,
  createSilentLogger,
  InMemoryAccessRepository,
  seedActiveSession,
  sha256Hex,
} from './support/access-doubles.js';

const FIXED_NOW = new Date('2026-10-08T12:00:00.000Z');
const IN_TEN_MINUTES = new Date(FIXED_NOW.getTime() + 10 * 60 * 1000);

describe('RevokeSession use case (CA-09)', () => {
  let repository: InMemoryAccessRepository;
  let logger: Logger;
  let useCase: RevokeSessionUseCase;
  let transactionContext: TransactionContext;
  let runCallCount: number;

  beforeEach(() => {
    repository = new InMemoryAccessRepository();
    logger = createSilentLogger();
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

    useCase = new RevokeSessionUseCase({
      repository,
      crypto: createFakeCrypto(),
      transactionRunner,
      clock,
      logger,
    });
  });

  function givenActiveSession() {
    return seedActiveSession(repository, { accessTokenExpiresAt: IN_TEN_MINUTES });
  }

  describe('revogação explícita', () => {
    it('revokes the session with the explicit_sign_out reason', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(repository.sessions[0]?.revokedAt).toBeInstanceOf(Date);
      expect(repository.sessions[0]?.revokedReason).toBe('explicit_sign_out');
    });

    it('revokes the access tokens of the session in the same transaction', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(repository.accessTokens.every((token) => token.revokedAt !== undefined)).toBe(true);
      expect(runCallCount).toBe(1);
      expect(repository.seenContexts.every((context) => context === transactionContext)).toBe(true);
      expect(repository.operations).toEqual([
        'findSessionByAccessToken',
        'revokeSessionById',
        'revokeAccessTokensForSession',
        'revokePushDevicesForSession',
      ]);
    });

    it('revokes the push device registered for the session (CA-09)', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(repository.pushDevices).toHaveLength(1);
      expect(repository.pushDevices[0]?.revokedAt).toBeInstanceOf(Date);
    });

    it('leaves the push device of another session untouched', async () => {
      const seeded = givenActiveSession();
      repository.pushDevices.push({
        pushDeviceId: 'push-device-other-session',
        sessionId: 'session-of-another-installation',
        revokedAt: undefined,
      });

      await useCase.execute({ accessToken: seeded.accessToken });

      const other = repository.pushDevices.find(
        (device) => device.sessionId === 'session-of-another-installation',
      );
      expect(other?.revokedAt).toBeUndefined();
    });

    it('keeps the member in the family (CA-09)', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(repository.members).toEqual([
        {
          memberId: seeded.memberId,
          familyId: seeded.familyId,
          role: 'administrator',
          isFamilyCreator: true,
        },
      ]);
    });

    it('emits the session_revoked security log once', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      expect(logger.info).toHaveBeenCalledTimes(1);
      expect(logger.info).toHaveBeenCalledWith('session_revoked', {
        sessionId: seeded.sessionId,
        reason: 'explicit_sign_out',
      });
    });

    it('logs no token or hash alongside the event', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      const logged = JSON.stringify(
        (logger.info as unknown as { mock: { calls: unknown[] } }).mock.calls,
      );
      expect(logged).not.toContain(seeded.accessToken);
      expect(logged).not.toContain(sha256Hex(seeded.accessToken));
    });

    it('returns nothing, so the route has no body to send', async () => {
      const seeded = givenActiveSession();

      await expect(useCase.execute({ accessToken: seeded.accessToken })).resolves.toBeUndefined();
    });
  });

  describe('CA-05: token recusado depois da revogação', () => {
    it('rejects a second revocation of the same session with SESSION_REVOKED', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionRevokedError,
      );
    });

    it('does not duplicate the security log on a second revocation', async () => {
      const seeded = givenActiveSession();

      await useCase.execute({ accessToken: seeded.accessToken });
      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionRevokedError,
      );

      expect(logger.info).toHaveBeenCalledTimes(1);
    });
  });

  describe('token inválido ou expirado', () => {
    it('rejects an unknown access token with SESSION_EXPIRED', async () => {
      await expect(useCase.execute({ accessToken: 'never-issued' })).rejects.toThrow(
        SessionExpiredError,
      );
    });

    it('rejects an expired access token with SESSION_EXPIRED', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: new Date(FIXED_NOW.getTime() - 1000),
      });

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionExpiredError,
      );
    });

    it('revokes nothing when the token is not accepted', async () => {
      const seeded = seedActiveSession(repository, {
        accessTokenExpiresAt: new Date(FIXED_NOW.getTime() - 1000),
      });

      await expect(useCase.execute({ accessToken: seeded.accessToken })).rejects.toThrow(
        SessionExpiredError,
      );

      expect(repository.sessions[0]?.revokedAt).toBeUndefined();
      expect(repository.accessTokens[0]?.revokedAt).toBeUndefined();
      expect(repository.pushDevices[0]?.revokedAt).toBeUndefined();
      expect(logger.info).not.toHaveBeenCalled();
    });
  });
});
