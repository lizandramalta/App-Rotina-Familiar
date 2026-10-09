/**
 * Casos de uso do ingresso por convite — SPEC-005 Fase 1.
 *
 * Cobre CA-01 a CA-05, CA-07 e CA-08 com dublês coerentes; a garantia de
 * consumo único e de locks reais é provada em tests/integration.
 */
import { beforeEach, describe, expect, it } from 'vitest';
import { InspectInviteUseCase } from '../../src/modules/access/application/inspect-invite-use-case.js';
import { JoinFamilyByInviteUseCase } from '../../src/modules/access/application/join-family-by-invite-use-case.js';
import { RecoverInviteJoinUseCase } from '../../src/modules/access/application/recover-invite-join-use-case.js';
import { SessionIssuer } from '../../src/modules/access/application/session-issuer.js';
import { AccessTokenInvalidError } from '../../src/modules/access/domain/access-errors.js';
import { AesGcmInviteJoinEnvelope } from '../../src/modules/access/infrastructure/aes-gcm-invite-join-envelope.js';
import { createPasswordVerifier } from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';
import { ScryptInvitePasswordVerifier } from '../../src/modules/access/infrastructure/scrypt-invite-password-verifier.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type { TransactionRunner } from '../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { createRecordingLogger } from '../support/fake-logger.js';
import {
  createFakeCrypto,
  InMemoryAccessRepository,
  seedActiveSession,
  sha256Hex,
} from './support/access-doubles.js';
import {
  InMemoryInviteAttemptLimiter,
  InMemoryInviteJoinRepository,
  type StoredInvite,
} from './support/invite-join-doubles.js';

const NOW = new Date('2026-10-09T15:00:00.000Z');
const TOKEN = 'invite-token-value';
const PASSWORD = 'K7M2QX';
const ATTEMPT_ID = '5d1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';
const ATTEMPT_SECRET = 'attempt-secret-0123456789';
const PROOF = 'installation-proof-value';
const ORIGIN = '203.0.113.7';

describe('Invite join use cases (SPEC-005 phase 1)', () => {
  let accessRepository: InMemoryAccessRepository;
  let joinRepository: InMemoryInviteJoinRepository;
  let limiter: InMemoryInviteAttemptLimiter;
  let now: Date;
  let logs: ReturnType<typeof createRecordingLogger>;
  let inspect: InspectInviteUseCase;
  let join: JoinFamilyByInviteUseCase;
  let recover: RecoverInviteJoinUseCase;
  let invite: StoredInvite;
  let authenticateAs: ActorContext | undefined;

  const policy = { originLimit: 30, inviteLimit: 5, windowMs: 15 * 60 * 1000 };

  const joinCommand = (
    overrides: Partial<Parameters<JoinFamilyByInviteUseCase['execute']>[0]> = {},
  ) => ({
    token: TOKEN,
    password: PASSWORD,
    attemptId: ATTEMPT_ID,
    attemptSecret: ATTEMPT_SECRET,
    installationProof: PROOF,
    switchConfirmed: false,
    previousAccessToken: undefined,
    origin: ORIGIN,
    requestId: 'req-1',
    ...overrides,
  });

  const recoverCommand = (
    overrides: Partial<Parameters<RecoverInviteJoinUseCase['execute']>[0]> = {},
  ) => ({
    attemptId: ATTEMPT_ID,
    attemptSecret: ATTEMPT_SECRET,
    installationProof: PROOF,
    origin: ORIGIN,
    requestId: 'req-2',
    ...overrides,
  });

  beforeEach(async () => {
    accessRepository = new InMemoryAccessRepository();
    joinRepository = new InMemoryInviteJoinRepository(accessRepository);
    limiter = new InMemoryInviteAttemptLimiter();
    now = NOW;
    logs = createRecordingLogger();
    authenticateAs = undefined;

    invite = {
      inviteId: 'invite-1',
      familyId: 'family-1',
      memberId: 'member-guest',
      status: 'available',
      tokenHash: sha256Hex(TOKEN),
      passwordVerifier: await createPasswordVerifier(PASSWORD),
      role: MemberRole.KIDS,
      isFamilyCreator: false,
    };
    joinRepository.invites.push(invite);

    const crypto = createFakeCrypto();
    const clock: Clock = { now: () => now, nowIsoString: () => now.toISOString() };
    const transactionRunner: TransactionRunner = {
      run: async (work) => work({ client: {} }),
      forFamily: async (_familyId, work) => work({ client: {} }),
    };
    const envelope = new AesGcmInviteJoinEnvelope('test-invite-envelope-key-min-16-chars');

    inspect = new InspectInviteUseCase({
      repository: joinRepository,
      limiter,
      crypto,
      transactionRunner,
      clock,
      logger: logs.logger,
      policy,
    });
    join = new JoinFamilyByInviteUseCase({
      repository: joinRepository,
      accessRepository,
      sessionIssuer: new SessionIssuer({
        repository: accessRepository,
        crypto,
        logger: logs.logger,
      }),
      authenticate: {
        execute: async () => {
          if (authenticateAs === undefined) {
            throw new AccessTokenInvalidError();
          }
          return authenticateAs;
        },
      },
      passwordVerifier: new ScryptInvitePasswordVerifier(),
      envelope,
      limiter,
      crypto,
      transactionRunner,
      clock,
      logger: logs.logger,
      policy,
    });
    recover = new RecoverInviteJoinUseCase({
      repository: joinRepository,
      envelope,
      limiter,
      crypto,
      transactionRunner,
      clock,
      logger: logs.logger,
      policy,
    });
  });

  describe('InspectInvite — CA-01/CA-04', () => {
    it('CA-01 returns only the available status', async () => {
      const result = await inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' });
      expect(result).toEqual({ status: 'available' });
    });

    it.each(['consumed', 'invalidated'] as const)(
      'CA-04 answers INVITE_UNAVAILABLE for a %s invite',
      async (status) => {
        invite.status = status;
        await expect(
          inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' }),
        ).rejects.toMatchObject({ code: 'INVITE_UNAVAILABLE', statusCode: 404 });
      },
    );

    it('CA-04 gives the same answer for an unknown token', async () => {
      await expect(
        inspect.execute({ token: 'unknown', origin: ORIGIN, requestId: 'r' }),
      ).rejects.toMatchObject({ code: 'INVITE_UNAVAILABLE', statusCode: 404 });
    });

    it('answers RATE_LIMITED when the origin exceeds the limit', async () => {
      for (let attempt = 0; attempt < policy.originLimit; attempt += 1) {
        await inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' });
      }
      await expect(
        inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' }),
      ).rejects.toMatchObject({ code: 'RATE_LIMITED', statusCode: 429 });
    });

    it('answers DEPENDENCY_UNAVAILABLE when the limiter fails', async () => {
      limiter.throwOnUse = true;
      await expect(
        inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' }),
      ).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE', statusCode: 503 });
    });
  });

  describe('JoinFamilyByInvite — CA-02/CA-03/CA-04/CA-05', () => {
    it('CA-02 consumes the invite and opens the session of the invited profile only', async () => {
      const session = await join.execute(joinCommand());

      expect(session).toMatchObject({
        memberId: 'member-guest',
        familyId: 'family-1',
        role: MemberRole.KIDS,
        isFamilyCreator: false,
      });
      expect(session.accessToken).toBeTruthy();
      expect(session.refreshToken).toBeTruthy();
      expect(invite.status).toBe('consumed');
      expect(accessRepository.insertedSessions).toHaveLength(1);
      expect(accessRepository.insertedSessions[0]).toMatchObject({
        familyId: 'family-1',
        memberId: 'member-guest',
        installationProofHash: sha256Hex(PROOF),
      });
    });

    it('stores only hashes and an envelope, never the proofs or tokens in clear', async () => {
      const session = await join.execute(joinCommand());
      const [recovery] = joinRepository.recoveries;

      expect(recovery?.attemptSecretHash).toBe(sha256Hex(ATTEMPT_SECRET));
      expect(recovery?.installationProofHash).toBe(sha256Hex(PROOF));
      expect(recovery?.expiresAt.getTime()).toBe(NOW.getTime() + 10 * 60 * 1000);
      const serialized = JSON.stringify(recovery);
      for (const secret of [
        ATTEMPT_SECRET,
        PROOF,
        PASSWORD,
        session.accessToken,
        session.refreshToken,
      ]) {
        expect(serialized).not.toContain(secret);
      }
    });

    it('CA-03 answers INVITE_PASSWORD_INVALID without consuming the invite', async () => {
      await expect(join.execute(joinCommand({ password: 'WRONG1' }))).rejects.toMatchObject({
        code: 'INVITE_PASSWORD_INVALID',
        statusCode: 422,
      });

      expect(invite.status).toBe('available');
      expect(accessRepository.insertedSessions).toHaveLength(0);
      expect(joinRepository.recoveries).toHaveLength(0);
    });

    it('CA-03 applies RATE_LIMITED after repeated attempts and still does not consume', async () => {
      for (let attempt = 0; attempt < policy.inviteLimit; attempt += 1) {
        await expect(join.execute(joinCommand({ password: 'WRONG1' }))).rejects.toMatchObject({
          code: 'INVITE_PASSWORD_INVALID',
        });
      }

      // Mesmo a senha correta é recusada: o limite vale para o convite.
      await expect(join.execute(joinCommand())).rejects.toMatchObject({
        code: 'RATE_LIMITED',
        statusCode: 429,
      });
      expect(invite.status).toBe('available');
    });

    it.each(['consumed', 'invalidated'] as const)(
      'CA-04 answers INVITE_UNAVAILABLE for a %s invite',
      async (status) => {
        invite.status = status;
        await expect(join.execute(joinCommand())).rejects.toMatchObject({
          code: 'INVITE_UNAVAILABLE',
          statusCode: 404,
        });
        expect(accessRepository.insertedSessions).toHaveLength(0);
      },
    );

    it('CA-04 does not issue a session for a Creator profile', async () => {
      invite.isFamilyCreator = true;
      await expect(join.execute(joinCommand())).rejects.toMatchObject({
        code: 'INVITE_UNAVAILABLE',
      });
      expect(invite.status).toBe('available');
    });

    it('CA-05 turns the second of two concurrent attempts into INVITE_UNAVAILABLE', async () => {
      const [first, second] = await Promise.allSettled([
        join.execute(joinCommand({ attemptId: '11111111-1111-4111-8111-111111111111' })),
        join.execute(joinCommand({ attemptId: '22222222-2222-4222-8222-222222222222' })),
      ]);

      const fulfilled = [first, second].filter((result) => result.status === 'fulfilled');
      expect(fulfilled).toHaveLength(1);
      expect(accessRepository.insertedSessions).toHaveLength(1);
      const rejected = [first, second].find((result) => result.status === 'rejected');
      expect((rejected as PromiseRejectedResult).reason).toMatchObject({
        code: 'INVITE_UNAVAILABLE',
      });
    });

    it('ignores nothing from the client: no family, member or role field exists in the command', async () => {
      const session = await join.execute(
        joinCommand({
          ...({
            familyId: 'attacker-family',
            memberId: 'attacker',
            role: 'administrator',
          } as object),
        }),
      );
      expect(session).toMatchObject({ familyId: 'family-1', memberId: 'member-guest' });
    });
  });

  describe('access switch — SPEC-005 §5.2', () => {
    function givenPreviousSession() {
      const previous = seedActiveSession(accessRepository, {
        sessionId: 'session-previous',
        memberId: 'member-previous',
        familyId: 'family-previous',
        accessToken: 'previous-access-token',
        accessTokenExpiresAt: new Date(NOW.getTime() + 60_000),
        role: MemberRole.MEMBER,
        isFamilyCreator: false,
      });
      authenticateAs = {
        sessionId: previous.sessionId,
        familyId: previous.familyId,
        memberId: previous.memberId,
        role: MemberRole.MEMBER,
        isFamilyCreator: false,
      };
      return previous;
    }

    it('answers 409 and touches nothing when the switch is not confirmed', async () => {
      const previous = givenPreviousSession();

      await expect(
        join.execute(joinCommand({ previousAccessToken: 'previous-access-token' })),
      ).rejects.toMatchObject({
        code: 'ACCESS_SWITCH_CONFIRMATION_REQUIRED',
        statusCode: 409,
      });

      expect(invite.status).toBe('available');
      expect(
        accessRepository.sessions.find((item) => item.sessionId === previous.sessionId)?.revokedAt,
      ).toBeUndefined();
    });

    it('revokes the previous session, its tokens and push device only on success, keeping its member', async () => {
      const previous = givenPreviousSession();

      const session = await join.execute(
        joinCommand({ previousAccessToken: 'previous-access-token', switchConfirmed: true }),
      );

      const old = accessRepository.sessions.find((item) => item.sessionId === previous.sessionId);
      expect(old?.revokedAt).toBeDefined();
      expect(
        accessRepository.accessTokens.find((item) => item.sessionId === previous.sessionId)
          ?.revokedAt,
      ).toBeDefined();
      expect(
        accessRepository.pushDevices.find((item) => item.sessionId === previous.sessionId)
          ?.revokedAt,
      ).toBeDefined();
      expect(accessRepository.members.some((item) => item.memberId === previous.memberId)).toBe(
        true,
      );
      expect(session.memberId).toBe('member-guest');
    });

    it('answers SESSION_INVALID for an invalid previous credential', async () => {
      authenticateAs = undefined;
      await expect(
        join.execute(joinCommand({ previousAccessToken: 'garbage', switchConfirmed: true })),
      ).rejects.toMatchObject({ code: 'SESSION_INVALID', statusCode: 401 });
      expect(invite.status).toBe('available');
    });

    it('keeps the previous session when the join fails after validation', async () => {
      const previous = givenPreviousSession();

      await expect(
        join.execute(
          joinCommand({
            previousAccessToken: 'previous-access-token',
            switchConfirmed: true,
            password: 'WRONG1',
          }),
        ),
      ).rejects.toMatchObject({ code: 'INVITE_PASSWORD_INVALID' });

      expect(
        accessRepository.sessions.find((item) => item.sessionId === previous.sessionId)?.revokedAt,
      ).toBeUndefined();
    });
  });

  describe('uncertain result — SPEC-005 §5.4', () => {
    it('answers JOIN_RESULT_UNCERTAIN when the write fails inside the commit', async () => {
      joinRepository.failOnInsertRecovery = true;

      await expect(join.execute(joinCommand())).rejects.toMatchObject({
        code: 'JOIN_RESULT_UNCERTAIN',
        statusCode: 503,
      });
    });

    it('answers a plain DEPENDENCY_UNAVAILABLE when it fails before the commit', async () => {
      limiter.throwOnUse = true;
      await expect(join.execute(joinCommand())).rejects.toMatchObject({
        code: 'DEPENDENCY_UNAVAILABLE',
      });
    });
  });

  describe('RecoverInviteJoin — CA-07/CA-08', () => {
    it('CA-07 returns the same session without consuming the invite again', async () => {
      const original = await join.execute(joinCommand());
      const sessionsBefore = accessRepository.insertedSessions.length;

      now = new Date(NOW.getTime() + 9 * 60 * 1000);
      const recovered = await recover.execute(recoverCommand());

      expect(recovered).toEqual(original);
      expect(accessRepository.insertedSessions).toHaveLength(sessionsBefore);
      expect(invite.status).toBe('consumed');
    });

    it('CA-08 is unavailable after the ten minute window and removes the envelope', async () => {
      await join.execute(joinCommand());

      now = new Date(NOW.getTime() + 10 * 60 * 1000 + 1);
      await expect(recover.execute(recoverCommand())).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
        statusCode: 404,
      });
      expect(joinRepository.recoveries).toHaveLength(0);
    });

    it.each([
      ['attempt secret', { attemptSecret: 'another-secret-0123456789' }],
      ['installation proof', { installationProof: 'another-installation-proof' }],
      ['attempt id', { attemptId: '99999999-9999-4999-8999-999999999999' }],
    ])('CA-08 is unavailable for a wrong %s', async (_label, override) => {
      await join.execute(joinCommand());
      await expect(recover.execute(recoverCommand(override))).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });
    });

    it('CA-08 is unavailable once the recoverable session was revoked', async () => {
      const session = await join.execute(joinCommand());
      const stored = accessRepository.sessions.find((item) => item.sessionId === session.sessionId);
      if (stored !== undefined) {
        stored.revokedAt = NOW;
      }

      await expect(recover.execute(recoverCommand())).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });
    });

    it('does not accept a password or any public identifier as a substitute proof', async () => {
      await join.execute(joinCommand());
      await expect(
        recover.execute(recoverCommand({ attemptSecret: PASSWORD, installationProof: TOKEN })),
      ).rejects.toMatchObject({ code: 'JOIN_RECOVERY_UNAVAILABLE' });
    });
  });

  describe('expired envelopes', () => {
    it('purges vencidos envelopes of other joins in the commit of a new join', async () => {
      await join.execute(joinCommand());
      expect(joinRepository.recoveries).toHaveLength(1);

      // Outro convite, depois da janela do primeiro ingresso.
      const second: StoredInvite = {
        ...invite,
        inviteId: 'invite-2',
        memberId: 'member-second',
        tokenHash: sha256Hex('second-token'),
        status: 'available',
      };
      joinRepository.invites.push(second);
      now = new Date(NOW.getTime() + 11 * 60 * 1000);

      await join.execute(
        joinCommand({
          token: 'second-token',
          attemptId: '33333333-3333-4333-8333-333333333333',
          attemptSecret: 'another-attempt-secret-01',
        }),
      );

      expect(joinRepository.recoveries.map((item) => item.attemptId)).toEqual([
        '33333333-3333-4333-8333-333333333333',
      ]);
    });
  });

  describe('observability — SPEC-005 §8', () => {
    it('never logs token, password, proofs, verifiers or credentials', async () => {
      const session = await join.execute(joinCommand());
      await recover.execute(recoverCommand());
      await expect(join.execute(joinCommand({ password: 'WRONG1' }))).rejects.toThrow();
      await expect(
        inspect.execute({ token: TOKEN, origin: ORIGIN, requestId: 'r' }),
      ).rejects.toThrow();

      const serialized = JSON.stringify(logs.calls);
      for (const secret of [
        TOKEN,
        PASSWORD,
        'WRONG1',
        ATTEMPT_SECRET,
        PROOF,
        invite.passwordVerifier,
        invite.tokenHash,
        session.accessToken,
        session.refreshToken,
        ORIGIN,
      ]) {
        expect(serialized).not.toContain(secret);
      }
      expect(serialized).toContain('invite_join_confirmed');
      expect(serialized).toContain('invite_join_recovery');
      expect(serialized).toContain('invite_join_denied');
    });
  });
});
