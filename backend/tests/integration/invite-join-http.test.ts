/**
 * Jornada HTTP completa do convite (SPEC-004 → SPEC-005), sem dublês: o
 * Administrador emite o convite pela API, a pessoa convidada inspeciona, ingressa
 * e usa a sessão recebida, e a resposta perdida é recuperada. É a prova de que a
 * entrega "funciona" ponta a ponta no backend, além dos casos de uso isolados.
 */
import { createHash, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { buildHttpApp } from '../../src/presentation/http/app.js';

const INTEGRATION_TIMEOUT_MS = 120_000;
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Invite journey over HTTP',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    let app: FastifyInstance;
    const familyIds: string[] = [];
    const origins: string[] = [];

    beforeAll(async () => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      const config = loadConfiguration();
      container = createContainer(config);
      app = buildHttpApp(container, config);
      await app.ready();
    });

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
      await app?.close();
      await container?.dispose();
    }, INTEGRATION_TIMEOUT_MS);

    /** Família com Administrador autenticável por Bearer e um perfil Kids sem acesso. */
    async function seedFamily() {
      const familyId = randomUUID();
      const adminId = randomUUID();
      const kidsId = randomUUID();
      const adminToken = `admin-access-${randomUUID()}`;
      const sessionId = randomUUID();
      const db = container.dbPool;
      await db.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa HTTP', 'America/Sao_Paulo', now(), now())`,
        [familyId],
      );
      await db.query(
        `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $3, 'administrator', true, 'Criador', now(), now()),
                ($2, $3, 'kids', false, 'Criança', now(), now())`,
        [adminId, kidsId, familyId],
      );
      await db.query(
        `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
         values ($1, $2, $3, $4, 'admin-proof')`,
        [sessionId, familyId, adminId, `admin-refresh-${sessionId}`],
      );
      await db.query(
        `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
         values ($1, $2, $3, now() + interval '15 minutes')`,
        [randomUUID(), sessionId, sha256(adminToken)],
      );
      familyIds.push(familyId);
      return { familyId, adminId, kidsId, adminToken };
    }

    const post = (
      url: string,
      payload: Record<string, unknown>,
      options: { remoteAddress: string; authorization?: string } = {
        remoteAddress: '127.0.0.1',
      },
    ) => {
      if (!origins.includes(options.remoteAddress)) {
        origins.push(options.remoteAddress);
      }
      return app.inject({
        method: 'POST',
        url,
        payload,
        remoteAddress: options.remoteAddress,
        headers:
          options.authorization === undefined ? {} : { authorization: options.authorization },
      });
    };

    it('issues, inspects, joins, uses the session, recovers a lost response and refuses a replay', async () => {
      const family = await seedFamily();
      const guestOrigin = `10.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250)}.9`;

      // SPEC-004: o Administrador emite o convite do perfil Kids.
      const issued = await app.inject({
        method: 'POST',
        url: `/v1/family/members/${family.kidsId}/invites`,
        headers: { authorization: `Bearer ${family.adminToken}` },
      });
      expect(issued.statusCode).toBe(201);
      const { link, password } = issued.json<{ link: string; password: string }>();
      const token = link.split('/invite/')[1] ?? '';
      expect(token.length).toBeGreaterThan(20);

      // CA-01: inspeção neutra, sem nenhum dado do perfil ou da família.
      const inspected = await post(
        '/v1/access/invites/inspect',
        { token },
        { remoteAddress: guestOrigin },
      );
      expect(inspected.statusCode).toBe(200);
      expect(inspected.headers['cache-control']).toBe('no-store');
      expect(inspected.json()).toEqual({ status: 'available' });

      // CA-03: senha errada não consome e responde 422.
      const attempt = {
        attemptId: randomUUID(),
        attemptSecret: `secret-${randomUUID()}`,
        installationProof: `proof-${randomUUID()}`,
      };
      const wrong = await post(
        '/v1/access/invite-joins',
        { token, password: 'WRONG1', switchConfirmed: false, ...attempt },
        { remoteAddress: guestOrigin },
      );
      expect(wrong.statusCode).toBe(422);
      expect(wrong.json()).toMatchObject({ code: 'INVITE_PASSWORD_INVALID' });

      // CA-02: ingresso válido; família, perfil e papel vêm do convite.
      const joined = await post(
        '/v1/access/invite-joins',
        { token, password, switchConfirmed: false, ...attempt },
        { remoteAddress: guestOrigin },
      );
      expect(joined.statusCode).toBe(201);
      expect(joined.headers['cache-control']).toBe('no-store');
      const session = joined.json<{
        memberId: string;
        familyId: string;
        role: string;
        isFamilyCreator: boolean;
        accessToken: string;
        refreshToken: string;
      }>();
      expect(session).toMatchObject({
        memberId: family.kidsId,
        familyId: family.familyId,
        role: 'kids',
        isFamilyCreator: false,
      });

      // A sessão recebida autentica de verdade nas rotas protegidas.
      const me = await app.inject({
        method: 'GET',
        url: '/v1/me/session',
        headers: { authorization: `Bearer ${session.accessToken}` },
      });
      expect(me.statusCode).toBe(200);
      expect(me.json()).toMatchObject({ memberId: family.kidsId, role: 'kids' });

      // O refresh token estável renova o acesso, preso à instalação do ingresso.
      const refreshed = await app.inject({
        method: 'POST',
        url: '/v1/access/refresh',
        headers: { 'x-installation-proof': attempt.installationProof },
        payload: { refreshToken: session.refreshToken },
      });
      expect(refreshed.statusCode).toBe(200);

      // CA-04/CA-05: o convite consumido é indisponível, inclusive na inspeção.
      const replay = await post(
        '/v1/access/invite-joins',
        { token, password, switchConfirmed: false, ...attempt, attemptId: randomUUID() },
        { remoteAddress: guestOrigin },
      );
      expect(replay.statusCode).toBe(404);
      expect(replay.json()).toMatchObject({ code: 'INVITE_UNAVAILABLE' });
      const inspectedAgain = await post(
        '/v1/access/invites/inspect',
        { token },
        { remoteAddress: guestOrigin },
      );
      expect(inspectedAgain.statusCode).toBe(404);

      // CA-07: a resposta "perdida" é recuperada com as provas originais.
      const recovered = await post('/v1/access/invite-joins/recover', attempt, {
        remoteAddress: guestOrigin,
      });
      expect(recovered.statusCode).toBe(200);
      expect(recovered.json()).toMatchObject({
        sessionId: expect.any(String),
        memberId: family.kidsId,
        refreshToken: session.refreshToken,
      });

      // CA-08: prova errada recebe a resposta neutra.
      const denied = await post(
        '/v1/access/invite-joins/recover',
        { ...attempt, attemptSecret: `other-${randomUUID()}` },
        { remoteAddress: guestOrigin },
      );
      expect(denied.statusCode).toBe(404);
      expect(denied.json()).toMatchObject({ code: 'JOIN_RECOVERY_UNAVAILABLE' });
    });

    it('answers 429 with Retry-After after too many wrong passwords, then keeps the invite usable later', async () => {
      const family = await seedFamily();
      const origin = `10.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250)}.10`;
      const issued = await app.inject({
        method: 'POST',
        url: `/v1/family/members/${family.kidsId}/invites`,
        headers: { authorization: `Bearer ${family.adminToken}` },
      });
      const { link } = issued.json<{ link: string }>();
      const token = link.split('/invite/')[1] ?? '';
      const body = () => ({
        token,
        password: 'WRONG1',
        switchConfirmed: false,
        attemptId: randomUUID(),
        attemptSecret: `secret-${randomUUID()}`,
        installationProof: `proof-${randomUUID()}`,
      });

      const limit = container.config.INVITE_ATTEMPT_LIMIT;
      for (let attempt = 0; attempt < limit; attempt += 1) {
        const response = await post('/v1/access/invite-joins', body(), { remoteAddress: origin });
        expect(response.statusCode).toBe(422);
      }

      const blocked = await post('/v1/access/invite-joins', body(), { remoteAddress: origin });
      expect(blocked.statusCode).toBe(429);
      expect(blocked.headers['retry-after']).toBe(
        String(container.config.INVITE_ATTEMPT_WINDOW_MINUTES * 60),
      );
      expect(blocked.json()).toMatchObject({ code: 'RATE_LIMITED' });
    });

    it('replaces the local session only after a confirmed switch', async () => {
      const first = await seedFamily();
      const second = await seedFamily();
      const origin = `10.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250)}.11`;
      const issued = await app.inject({
        method: 'POST',
        url: `/v1/family/members/${second.kidsId}/invites`,
        headers: { authorization: `Bearer ${second.adminToken}` },
      });
      const { link, password } = issued.json<{ link: string; password: string }>();
      const token = link.split('/invite/')[1] ?? '';
      const attempt = () => ({
        token,
        password,
        attemptId: randomUUID(),
        attemptSecret: `secret-${randomUUID()}`,
        installationProof: `proof-${randomUUID()}`,
      });
      const bearer = `Bearer ${first.adminToken}`;

      // CA-06 (lado servidor): sem confirmação, 409 e a sessão anterior segue ativa.
      const unconfirmed = await post(
        '/v1/access/invite-joins',
        { ...attempt(), switchConfirmed: false },
        { remoteAddress: origin, authorization: bearer },
      );
      expect(unconfirmed.statusCode).toBe(409);
      expect(unconfirmed.json()).toMatchObject({ code: 'ACCESS_SWITCH_CONFIRMATION_REQUIRED' });
      const stillWorks = await app.inject({
        method: 'GET',
        url: '/v1/me/session',
        headers: { authorization: bearer },
      });
      expect(stillWorks.statusCode).toBe(200);

      // Confirmada: ingressa e a credencial anterior deixa de valer.
      const confirmed = await post(
        '/v1/access/invite-joins',
        { ...attempt(), switchConfirmed: true },
        { remoteAddress: origin, authorization: bearer },
      );
      expect(confirmed.statusCode).toBe(201);
      const revoked = await app.inject({
        method: 'GET',
        url: '/v1/me/session',
        headers: { authorization: bearer },
      });
      expect(revoked.statusCode).toBe(401);
    });

    it('rejects client supplied family, member and role with UNKNOWN_FIELD', async () => {
      const origin = `10.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250)}.12`;
      const response = await post(
        '/v1/access/invite-joins',
        {
          token: 't',
          password: 'K7M2QX',
          attemptId: randomUUID(),
          attemptSecret: 'attempt-secret-0123456789',
          installationProof: 'proof',
          switchConfirmed: false,
          familyId: randomUUID(),
          role: 'administrator',
        },
        { remoteAddress: origin },
      );
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'UNKNOWN_FIELD' });
    });
  },
);
