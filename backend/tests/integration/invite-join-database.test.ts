/**
 * Ingresso por convite em PostgreSQL real (SPEC-005 Fase 1 / SCRUM-32).
 *
 * Valida o que os dublês unitários não alcançam: consumo único sob concorrência
 * (CA-05), atomicidade do commit, revogação da sessão anterior só no sucesso,
 * recuperação sem segundo consumo (CA-07/CA-08) e ausência de segredos legíveis
 * nas tabelas.
 */
import { createHash, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { JoinFamilyByInviteUseCase } from '../../src/modules/access/application/join-family-by-invite-use-case.js';
import type { InviteJoinRepositoryPort } from '../../src/modules/access/application/invite-join-repository-port.js';
import { SessionIssuer } from '../../src/modules/access/application/session-issuer.js';
import { AesGcmInviteJoinEnvelope } from '../../src/modules/access/infrastructure/aes-gcm-invite-join-envelope.js';
import { CryptoTokenService } from '../../src/modules/access/infrastructure/crypto-token-service.js';
import { PostgresInviteAttemptLimiter } from '../../src/modules/access/infrastructure/postgres-invite-attempt-limiter.js';
import { PostgresInviteJoinRepository } from '../../src/modules/access/infrastructure/postgres-invite-join-repository.js';
import { ScryptInvitePasswordVerifier } from '../../src/modules/access/infrastructure/scrypt-invite-password-verifier.js';
import {
  createPasswordVerifier,
  hashInviteToken,
} from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const INTEGRATION_TIMEOUT_MS = 60_000;
const PASSWORD = 'K7M2QX';
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

interface SeededInvite {
  readonly familyId: string;
  readonly creatorId: string;
  readonly guestId: string;
  readonly guestRole: 'kids' | 'member' | 'administrator';
  readonly inviteId: string;
  readonly token: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Invite join persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    const familyIds: string[] = [];
    const origins: string[] = [];
    let passwordVerifier: string;

    beforeAll(async () => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
      passwordVerifier = await createPasswordVerifier(PASSWORD);
    });

    // Em lote e com prazo próprio: contra um banco remoto cada ida e volta custa
    // segundos, e uma exclusão por família estourava o prazo padrão de 10 s do
    // hook, deixando dados de teste para trás.
    afterAll(async () => {
      if (container !== undefined) {
        await container.dbPool.query('delete from app.families where id = any($1::uuid[])', [
          familyIds,
        ]);
        await container.dbPool.query(
          'delete from app.invite_attempt_log where subject_hash = any($1::text[])',
          [origins.map((origin) => sha256(`origin:${origin}`))],
        );
      }
      await container?.dispose();
    }, INTEGRATION_TIMEOUT_MS);

    const newOrigin = () => {
      const origin = `198.51.100.${Math.floor(Math.random() * 250)}-${randomUUID()}`;
      origins.push(origin);
      return origin;
    };

    async function seedInvite(
      guestRole: SeededInvite['guestRole'] = 'kids',
      options: { activeGuestSession?: boolean } = {},
    ): Promise<SeededInvite> {
      const seeded: SeededInvite = {
        familyId: randomUUID(),
        creatorId: randomUUID(),
        guestId: randomUUID(),
        guestRole,
        inviteId: randomUUID(),
        token: `token-${randomUUID()}`,
      };
      const db = container.dbPool;
      const now = new Date();
      await db.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [seeded.familyId, now],
      );
      await db.query(
        `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $3, 'administrator', true, 'Criador', $4, $4),
                ($2, $3, $5, false, 'Convidado', $4, $4)`,
        [seeded.creatorId, seeded.guestId, seeded.familyId, now, guestRole],
      );
      await db.query(
        `insert into app.member_invites
           (id, family_id, member_id, issued_by_member_id, token_hash, password_verifier, status, created_at)
         values ($1, $2, $3, $4, $5, $6, 'available', $7)`,
        [
          seeded.inviteId,
          seeded.familyId,
          seeded.guestId,
          seeded.creatorId,
          hashInviteToken(seeded.token),
          passwordVerifier,
          now,
        ],
      );
      if (options.activeGuestSession === true) {
        await db.query(
          `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
           values ($1, $2, $3, $4, 'old-proof')`,
          [randomUUID(), seeded.familyId, seeded.guestId, `old-refresh-${randomUUID()}`],
        );
      }
      familyIds.push(seeded.familyId);
      return seeded;
    }

    /** Sessão local de outra pessoa, autenticável por Bearer. */
    async function seedPreviousSession() {
      const familyId = randomUUID();
      const memberId = randomUUID();
      const sessionId = randomUUID();
      const accessToken = `previous-access-${randomUUID()}`;
      const db = container.dbPool;
      await db.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Outra casa', 'America/Sao_Paulo', now(), now())`,
        [familyId],
      );
      await db.query(
        `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $2, 'member', false, 'Anterior', now(), now())`,
        [memberId, familyId],
      );
      await db.query(
        `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
         values ($1, $2, $3, $4, 'prev-proof')`,
        [sessionId, familyId, memberId, `prev-refresh-${sessionId}`],
      );
      await db.query(
        `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
         values ($1, $2, $3, now() + interval '15 minutes')`,
        [randomUUID(), sessionId, sha256(accessToken)],
      );
      await db.query(
        `insert into app.push_devices (id, session_id, device_token, environment)
         values ($1, $2, $3, 'development')`,
        [randomUUID(), sessionId, `device-${sessionId}`],
      );
      familyIds.push(familyId);
      return { familyId, memberId, sessionId, accessToken };
    }

    const joinInput = (seeded: SeededInvite, overrides: Record<string, unknown> = {}) => ({
      token: seeded.token,
      password: PASSWORD,
      attemptId: randomUUID(),
      attemptSecret: `secret-${randomUUID()}`,
      installationProof: `proof-${randomUUID()}`,
      switchConfirmed: false,
      previousAccessToken: undefined,
      origin: newOrigin(),
      requestId: 'integration',
      ...overrides,
    });

    const inviteStatus = async (inviteId: string) =>
      (
        await container.dbPool.query<{ status: string }>(
          'select status from app.member_invites where id = $1',
          [inviteId],
        )
      ).rows[0]?.status;

    const activeSessionsOf = async (memberId: string) =>
      (
        await container.dbPool.query<{ id: string }>(
          'select id from app.sessions where member_id = $1 and revoked_at is null',
          [memberId],
        )
      ).rows;

    it('CA-01 inspects an available invite revealing only its availability', async () => {
      const seeded = await seedInvite();
      const result = await container.inspectInviteUseCase.execute({
        token: seeded.token,
        origin: newOrigin(),
        requestId: 'i1',
      });

      expect(result).toEqual({ status: 'available' });
    });

    it('CA-04 answers the same unavailable error for unknown, consumed and invalidated tokens', async () => {
      const consumed = await seedInvite();
      await container.dbPool.query(
        `update app.member_invites set status = 'consumed', consumed_at = now() where id = $1`,
        [consumed.inviteId],
      );
      const invalidated = await seedInvite();
      await container.dbPool.query(
        `update app.member_invites set status = 'invalidated', invalidated_at = now() where id = $1`,
        [invalidated.inviteId],
      );

      const responses: unknown[] = [];
      for (const token of ['unknown-token', consumed.token, invalidated.token]) {
        const error = await container.inspectInviteUseCase
          .execute({ token, origin: newOrigin(), requestId: 'i2' })
          .catch((caught: unknown) => caught);
        responses.push({
          code: (error as { code: string }).code,
          status: (error as { statusCode: number }).statusCode,
          message: (error as Error).message,
        });
      }

      expect(new Set(responses.map((item) => JSON.stringify(item))).size).toBe(1);
      expect(responses[0]).toMatchObject({ code: 'INVITE_UNAVAILABLE', status: 404 });
    });

    it('CA-02 consumes the invite and opens the session of the invited profile, storing no clear secrets', async () => {
      const seeded = await seedInvite('kids');
      const input = joinInput(seeded);

      const session = await container.joinFamilyByInviteUseCase.execute(input);

      expect(session).toMatchObject({
        memberId: seeded.guestId,
        familyId: seeded.familyId,
        role: 'kids',
        isFamilyCreator: false,
      });
      expect(await inviteStatus(seeded.inviteId)).toBe('consumed');
      expect(await activeSessionsOf(seeded.guestId)).toHaveLength(1);

      const stored = await container.dbPool.query<Record<string, string>>(
        `select s.refresh_token_hash, s.installation_proof_hash, r.attempt_secret_hash,
                r.installation_proof_hash as recovery_proof_hash, r.envelope
           from app.sessions s
           join app.invite_join_recoveries r on r.session_id = s.id
          where s.id = $1`,
        [session.sessionId],
      );
      const row = stored.rows[0];
      expect(row?.refresh_token_hash).toBe(sha256(session.refreshToken));
      expect(row?.installation_proof_hash).toBe(sha256(input.installationProof));
      expect(row?.attempt_secret_hash).toBe(sha256(input.attemptSecret));
      const everything = JSON.stringify(row);
      for (const secret of [
        session.refreshToken,
        session.accessToken,
        input.attemptSecret,
        input.installationProof,
        PASSWORD,
      ]) {
        expect(everything).not.toContain(secret);
      }
    });

    it('CA-02 gives the role of the invited profile, never an adult capability to Kids', async () => {
      const kids = await seedInvite('kids');
      const adult = await seedInvite('administrator');

      const kidsSession = await container.joinFamilyByInviteUseCase.execute(joinInput(kids));
      const adultSession = await container.joinFamilyByInviteUseCase.execute(joinInput(adult));

      expect(kidsSession.role).toBe('kids');
      expect(adultSession.role).toBe('administrator');
    });

    it('CA-03 keeps the invite available after a wrong password and limits repeated attempts', async () => {
      const seeded = await seedInvite();
      const policyLimit = container.config.INVITE_ATTEMPT_LIMIT;

      for (let attempt = 0; attempt < policyLimit; attempt += 1) {
        await expect(
          container.joinFamilyByInviteUseCase.execute(joinInput(seeded, { password: 'WRONG1' })),
        ).rejects.toMatchObject({ code: 'INVITE_PASSWORD_INVALID', statusCode: 422 });
        expect(await inviteStatus(seeded.inviteId)).toBe('available');
      }
      expect(await activeSessionsOf(seeded.guestId)).toHaveLength(0);

      await expect(
        container.joinFamilyByInviteUseCase.execute(joinInput(seeded)),
      ).rejects.toMatchObject({ code: 'RATE_LIMITED', statusCode: 429 });
      expect(await inviteStatus(seeded.inviteId)).toBe('available');
    });

    it('CA-05 confirms one session and one consumption for two simultaneous attempts', async () => {
      const seeded = await seedInvite();

      const results = await Promise.allSettled([
        container.joinFamilyByInviteUseCase.execute(joinInput(seeded)),
        container.joinFamilyByInviteUseCase.execute(joinInput(seeded)),
      ]);

      const fulfilled = results.filter((result) => result.status === 'fulfilled');
      const rejected = results.filter(
        (result): result is PromiseRejectedResult => result.status === 'rejected',
      );
      expect(fulfilled).toHaveLength(1);
      expect(rejected).toHaveLength(1);
      expect(rejected[0]?.reason).toMatchObject({ code: 'INVITE_UNAVAILABLE', statusCode: 404 });
      expect(await activeSessionsOf(seeded.guestId)).toHaveLength(1);
      const sessions = await container.dbPool.query(
        'select id from app.sessions where member_id = $1',
        [seeded.guestId],
      );
      expect(sessions.rows).toHaveLength(1);
      const recoveries = await container.dbPool.query(
        'select attempt_id from app.invite_join_recoveries where invite_id = $1',
        [seeded.inviteId],
      );
      expect(recoveries.rows).toHaveLength(1);
    });

    it('CA-05 still yields a single session in a larger burst, the excess being 404 or rate limited', async () => {
      const seeded = await seedInvite();
      const attempts = 12;

      const results = await Promise.allSettled(
        Array.from({ length: attempts }, () =>
          container.joinFamilyByInviteUseCase.execute(joinInput(seeded)),
        ),
      );

      const fulfilled = results.filter((result) => result.status === 'fulfilled');
      const rejected = results.filter(
        (result): result is PromiseRejectedResult => result.status === 'rejected',
      );
      expect(fulfilled).toHaveLength(1);
      for (const failure of rejected) {
        expect(['INVITE_UNAVAILABLE', 'RATE_LIMITED']).toContain(
          (failure.reason as { code: string }).code,
        );
      }
      const sessions = await container.dbPool.query(
        'select id from app.sessions where member_id = $1',
        [seeded.guestId],
      );
      expect(sessions.rows).toHaveLength(1);
      expect(await inviteStatus(seeded.inviteId)).toBe('consumed');
    });

    it('replaces an older active session of the same profile without violating the one-session rule', async () => {
      const seeded = await seedInvite('member', { activeGuestSession: true });

      const session = await container.joinFamilyByInviteUseCase.execute(joinInput(seeded));

      const active = await activeSessionsOf(seeded.guestId);
      expect(active.map((row) => row.id)).toEqual([session.sessionId]);
    });

    it('revokes the previous session, its tokens and push device on a confirmed switch, keeping its member', async () => {
      const seeded = await seedInvite();
      const previous = await seedPreviousSession();

      await container.joinFamilyByInviteUseCase.execute(
        joinInput(seeded, { previousAccessToken: previous.accessToken, switchConfirmed: true }),
      );

      const db = container.dbPool;
      expect(
        (await db.query('select revoked_at from app.sessions where id = $1', [previous.sessionId]))
          .rows[0]?.revoked_at,
      ).not.toBeNull();
      expect(
        (
          await db.query('select revoked_at from app.session_access_tokens where session_id = $1', [
            previous.sessionId,
          ])
        ).rows[0]?.revoked_at,
      ).not.toBeNull();
      expect(
        (
          await db.query('select revoked_at from app.push_devices where session_id = $1', [
            previous.sessionId,
          ])
        ).rows[0]?.revoked_at,
      ).not.toBeNull();
      // O perfil anterior e sua família permanecem (RF68, RN09).
      expect(
        (await db.query('select id from app.members where id = $1', [previous.memberId])).rows,
      ).toHaveLength(1);
    });

    it('keeps the previous session untouched without confirmation or with a wrong password', async () => {
      const seeded = await seedInvite();
      const previous = await seedPreviousSession();
      const stillActive = async () =>
        (
          await container.dbPool.query<{ revoked_at: Date | null }>(
            'select revoked_at from app.sessions where id = $1',
            [previous.sessionId],
          )
        ).rows[0]?.revoked_at === null;

      await expect(
        container.joinFamilyByInviteUseCase.execute(
          joinInput(seeded, { previousAccessToken: previous.accessToken, switchConfirmed: false }),
        ),
      ).rejects.toMatchObject({ code: 'ACCESS_SWITCH_CONFIRMATION_REQUIRED', statusCode: 409 });
      expect(await stillActive()).toBe(true);

      await expect(
        container.joinFamilyByInviteUseCase.execute(
          joinInput(seeded, {
            previousAccessToken: previous.accessToken,
            switchConfirmed: true,
            password: 'WRONG1',
          }),
        ),
      ).rejects.toMatchObject({ code: 'INVITE_PASSWORD_INVALID' });
      expect(await stillActive()).toBe(true);
      expect(await inviteStatus(seeded.inviteId)).toBe('available');
    });

    it('rolls back the whole commit when the final write fails, leaving invite and previous session intact', async () => {
      const seeded = await seedInvite();
      const previous = await seedPreviousSession();
      const crypto = new CryptoTokenService(container.config.SESSION_SECRET);
      const real = new PostgresInviteJoinRepository();
      const failing: InviteJoinRepositoryPort = Object.assign(Object.create(real), {
        insertJoinRecovery: async () => {
          throw new Error('simulated failure after consuming');
        },
      }) as InviteJoinRepositoryPort;
      const { logger } = createRecordingLogger();

      const useCase = new JoinFamilyByInviteUseCase({
        repository: failing,
        accessRepository: container.accessRepository,
        sessionIssuer: new SessionIssuer({
          repository: container.accessRepository,
          crypto,
          logger,
        }),
        authenticate: container.authenticateSessionUseCase,
        passwordVerifier: new ScryptInvitePasswordVerifier(),
        envelope: new AesGcmInviteJoinEnvelope(container.config.INVITE_ENVELOPE_KEY),
        limiter: new PostgresInviteAttemptLimiter(container.dbPool),
        crypto,
        transactionRunner: container.transactionRunner,
        clock: container.clock,
        logger,
        policy: { originLimit: 100, inviteLimit: 100, windowMs: 60_000 },
      });

      await expect(
        useCase.execute(
          joinInput(seeded, { previousAccessToken: previous.accessToken, switchConfirmed: true }),
        ),
      ).rejects.toMatchObject({ code: 'JOIN_RESULT_UNCERTAIN', statusCode: 503 });

      expect(await inviteStatus(seeded.inviteId)).toBe('available');
      expect(await activeSessionsOf(seeded.guestId)).toHaveLength(0);
      expect(await activeSessionsOf(previous.memberId)).toHaveLength(1);
    });

    it('CA-07 returns the same session on recovery without consuming the invite again', async () => {
      const seeded = await seedInvite();
      const input = joinInput(seeded);
      const original = await container.joinFamilyByInviteUseCase.execute(input);

      const recovered = await container.recoverInviteJoinUseCase.execute({
        attemptId: input.attemptId,
        attemptSecret: input.attemptSecret,
        installationProof: input.installationProof,
        origin: newOrigin(),
        requestId: 'rec1',
      });

      expect(recovered).toEqual(original);
      const sessions = await container.dbPool.query(
        'select id from app.sessions where member_id = $1',
        [seeded.guestId],
      );
      expect(sessions.rows).toHaveLength(1);
      expect(await inviteStatus(seeded.inviteId)).toBe('consumed');
      // O mesmo refresh token continua autenticando a sessão recuperada.
      const refreshed = await container.refreshSessionUseCase.execute({
        refreshToken: recovered.refreshToken,
        installationProof: input.installationProof,
      });
      expect(refreshed.accessToken).toBeTruthy();
    });

    it('CA-08 is unavailable for wrong proofs, an expired window and a revoked session', async () => {
      const recoverWith = (
        input: ReturnType<typeof joinInput>,
        overrides: Record<string, string> = {},
      ) =>
        container.recoverInviteJoinUseCase.execute({
          attemptId: input.attemptId,
          attemptSecret: input.attemptSecret,
          installationProof: input.installationProof,
          origin: newOrigin(),
          requestId: 'rec2',
          ...overrides,
        });

      // Provas incompatíveis.
      const first = await seedInvite();
      const firstInput = joinInput(first);
      await container.joinFamilyByInviteUseCase.execute(firstInput);
      await expect(
        recoverWith(firstInput, { attemptSecret: 'wrong-secret-0123456789' }),
      ).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
        statusCode: 404,
      });
      await expect(
        recoverWith(firstInput, { installationProof: 'wrong-proof' }),
      ).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });
      await expect(recoverWith(firstInput, { attemptId: randomUUID() })).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });

      // Janela expirada: o envelope é removido na própria tentativa.
      await container.dbPool.query(
        `update app.invite_join_recoveries set expires_at = now() - interval '1 second'
          where attempt_id = $1`,
        [firstInput.attemptId],
      );
      await expect(recoverWith(firstInput)).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });
      expect(
        (
          await container.dbPool.query(
            'select 1 from app.invite_join_recoveries where attempt_id = $1',
            [firstInput.attemptId],
          )
        ).rows,
      ).toHaveLength(0);

      // Sessão recuperável revogada (por exemplo, por novo convite).
      const second = await seedInvite();
      const secondInput = joinInput(second);
      const session = await container.joinFamilyByInviteUseCase.execute(secondInput);
      await container.dbPool.query(
        `update app.sessions set revoked_at = now(), revoked_reason = 'INVITE_REISSUED' where id = $1`,
        [session.sessionId],
      );
      await expect(recoverWith(secondInput)).rejects.toMatchObject({
        code: 'JOIN_RECOVERY_UNAVAILABLE',
      });
    });

    it('does not let an invite of one family open a session in another (isolation)', async () => {
      const familyA = await seedInvite('member');
      const familyB = await seedInvite('member');

      const session = await container.joinFamilyByInviteUseCase.execute(joinInput(familyA));

      expect(session.familyId).toBe(familyA.familyId);
      expect(session.familyId).not.toBe(familyB.familyId);
      expect(await inviteStatus(familyB.inviteId)).toBe('available');
      expect(await activeSessionsOf(familyB.guestId)).toHaveLength(0);
    });

    it('CA-04 refuses a Creator profile even if an invite row targets it', async () => {
      const seeded = await seedInvite();
      await container.dbPool.query(`update app.member_invites set member_id = $1 where id = $2`, [
        seeded.creatorId,
        seeded.inviteId,
      ]);

      await expect(
        container.joinFamilyByInviteUseCase.execute(joinInput(seeded)),
      ).rejects.toMatchObject({ code: 'INVITE_UNAVAILABLE', statusCode: 404 });
      expect(await activeSessionsOf(seeded.creatorId)).toHaveLength(0);
    });
  },
);
