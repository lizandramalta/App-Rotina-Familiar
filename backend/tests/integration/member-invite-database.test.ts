/**
 * Emissão de convite em PostgreSQL real (SPEC-004 Fase 1).
 *
 * Valida o que os dublês unitários não alcançam: revogação atômica de sessão e
 * convites, o índice de "um disponível por perfil", isolamento entre famílias,
 * concorrência (CA-06) e rollback completo quando a escrita falha (CA-07).
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { IssueMemberInviteUseCase } from '../../src/modules/family/application/issue-member-invite-use-case.js';
import type { MemberInviteRepositoryPort } from '../../src/modules/family/application/member-invite-repository-port.js';
import { CryptoInviteCredentials } from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';
import { PostgresMemberInviteRepository } from '../../src/modules/family/infrastructure/postgres-member-invite-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const INTEGRATION_TIMEOUT_MS = 60_000;
const NOW = new Date('2026-10-09T15:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly creatorId: string;
  readonly adminId: string;
  readonly adminSessionId: string;
  readonly guestId: string;
  readonly guestSessionId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Member invite issuance persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    const repository = new PostgresMemberInviteRepository();
    const seeded: SeededFamily[] = [];

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of seeded) {
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
      }
      await container?.dispose();
    });

    const useCase = (override?: Partial<MemberInviteRepositoryPort>) =>
      new IssueMemberInviteUseCase({
        repository: Object.assign(
          Object.create(repository),
          override,
        ) as MemberInviteRepositoryPort,
        credentials: new CryptoInviteCredentials('https://app.example.test'),
        transactionRunner: container.transactionRunner,
        clock: { now: () => NOW, nowIsoString: () => NOW.toISOString() },
        logger: createRecordingLogger().logger,
      });

    async function seedFamily(): Promise<SeededFamily> {
      const family: SeededFamily = {
        familyId: randomUUID(),
        creatorId: randomUUID(),
        adminId: randomUUID(),
        adminSessionId: randomUUID(),
        guestId: randomUUID(),
        guestSessionId: randomUUID(),
      };
      const db = container.dbPool;
      await db.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, NOW],
      );
      const members: Array<[string, string, boolean]> = [
        [family.creatorId, 'administrator', true],
        [family.adminId, 'administrator', false],
        [family.guestId, 'member', false],
      ];
      for (const [id, role, creator] of members) {
        await db.query(
          `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, $3, $4, $5, $6, $6)`,
          [id, family.familyId, role, creator, `Member ${role}`, NOW],
        );
      }
      for (const [sessionId, memberId] of [
        [family.adminSessionId, family.adminId],
        [family.guestSessionId, family.guestId],
      ] as const) {
        await db.query(
          `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
           values ($1, $2, $3, $4, 'proof')`,
          [sessionId, family.familyId, memberId, `refresh-${sessionId}`],
        );
      }
      seeded.push(family);
      return family;
    }

    const adminOf = (family: SeededFamily): ActorContext => ({
      sessionId: family.adminSessionId,
      familyId: family.familyId,
      memberId: family.adminId,
      role: MemberRole.ADMINISTRATOR,
      isFamilyCreator: false,
    });

    const invitesOf = async (memberId: string) =>
      (
        await container.dbPool.query<{
          status: string;
          token_hash: string;
          password_verifier: string;
        }>(
          'select status, token_hash, password_verifier from app.member_invites where member_id = $1 order by created_at, id',
          [memberId],
        )
      ).rows;

    it('CA-01/CA-05 creates an available invite storing only protected verifiers', async () => {
      const family = await seedFamily();
      const result = await useCase().execute({
        actor: adminOf(family),
        memberId: family.guestId,
        requestId: 'r1',
      });

      const [row, ...rest] = await invitesOf(family.guestId);
      expect(rest).toHaveLength(0);
      expect(row?.status).toBe('available');
      const token = result.link.split('/invite/')[1] ?? '';
      expect(row?.token_hash).not.toBe(token);
      expect(row?.password_verifier).not.toContain(result.password);
      expect(row?.password_verifier).toMatch(/^scrypt\$v1\$/);
      // Perfil e histórico preservados.
      const member = await container.dbPool.query('select role from app.members where id = $1', [
        family.guestId,
      ]);
      expect(member.rows).toEqual([{ role: 'member' }]);
    });

    it('CA-02 reissuing invalidates the previous invite and revokes the session, tokens and push device', async () => {
      const family = await seedFamily();
      const db = container.dbPool;
      await db.query(
        `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
         values ($1, $2, $3, now() + interval '15 minutes')`,
        [randomUUID(), family.guestSessionId, `access-${family.guestSessionId}`],
      );
      await db.query(
        `insert into app.push_devices (id, session_id, device_token, environment)
         values ($1, $2, 'device-token', 'development')`,
        [randomUUID(), family.guestSessionId],
      );
      const input = { actor: adminOf(family), memberId: family.guestId, requestId: 'r2' };

      await useCase().execute(input);
      await useCase().execute(input);

      expect((await invitesOf(family.guestId)).map((row) => row.status).sort()).toEqual([
        'available',
        'invalidated',
      ]);
      const session = await db.query(
        'select revoked_at, revoked_reason from app.sessions where id = $1',
        [family.guestSessionId],
      );
      expect(session.rows[0]).toMatchObject({ revoked_reason: 'INVITE_REISSUED' });
      expect(session.rows[0]?.revoked_at).not.toBeNull();
      expect(
        (
          await db.query('select revoked_at from app.session_access_tokens where session_id = $1', [
            family.guestSessionId,
          ])
        ).rows[0]?.revoked_at,
      ).not.toBeNull();
      expect(
        (
          await db.query('select revoked_at from app.push_devices where session_id = $1', [
            family.guestSessionId,
          ])
        ).rows[0]?.revoked_at,
      ).not.toBeNull();
      // A sessão do Administrador que emitiu não é tocada.
      expect(
        (
          await db.query('select revoked_at from app.sessions where id = $1', [
            family.adminSessionId,
          ])
        ).rows[0]?.revoked_at,
      ).toBeNull();
    });

    it('CA-03 treats a member of another family as RESOURCE_NOT_FOUND and writes nothing', async () => {
      const family = await seedFamily();
      const foreign = await seedFamily();
      await expect(
        useCase().execute({ actor: adminOf(family), memberId: foreign.guestId, requestId: 'r3' }),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
      expect(await invitesOf(foreign.guestId)).toHaveLength(0);
      expect(
        (
          await container.dbPool.query('select revoked_at from app.sessions where id = $1', [
            foreign.guestSessionId,
          ])
        ).rows[0]?.revoked_at,
      ).toBeNull();
    });

    it('CA-03 refuses a stale actor session revoked before the lock', async () => {
      const family = await seedFamily();
      await container.dbPool.query('update app.sessions set revoked_at = now() where id = $1', [
        family.adminSessionId,
      ]);
      await expect(
        useCase().execute({ actor: adminOf(family), memberId: family.guestId, requestId: 'r4' }),
      ).rejects.toMatchObject({ statusCode: 401 });
      expect(await invitesOf(family.guestId)).toHaveLength(0);
    });

    it('CA-04 refuses the creator without creating credentials or revoking anything', async () => {
      const family = await seedFamily();
      await expect(
        useCase().execute({ actor: adminOf(family), memberId: family.creatorId, requestId: 'r5' }),
      ).rejects.toMatchObject({ code: 'INVITE_NOT_ISSUABLE' });
      expect(await invitesOf(family.creatorId)).toHaveLength(0);
    });

    it('CA-06 concurrent issuances leave exactly one available invite and no active session', async () => {
      const family = await seedFamily();
      const input = { actor: adminOf(family), memberId: family.guestId, requestId: 'r6' };

      const results = await Promise.all(Array.from({ length: 5 }, () => useCase().execute(input)));

      expect(new Set(results.map((result) => result.inviteId)).size).toBe(5);
      const statuses = (await invitesOf(family.guestId)).map((row) => row.status);
      expect(statuses.filter((status) => status === 'available')).toHaveLength(1);
      expect(statuses.filter((status) => status === 'invalidated')).toHaveLength(4);
      const active = await container.dbPool.query(
        'select 1 from app.sessions where member_id = $1 and revoked_at is null',
        [family.guestId],
      );
      expect(active.rowCount).toBe(0);
    });

    it('database refuses a second available invite for the same member even without the lock', async () => {
      const family = await seedFamily();
      const insert = () =>
        container.dbPool.query(
          `insert into app.member_invites
             (id, family_id, member_id, issued_by_member_id, token_hash, password_verifier, created_at)
           values ($1, $2, $3, $4, $5, 'v', now())`,
          [randomUUID(), family.familyId, family.guestId, family.adminId, randomUUID()],
        );
      await insert();
      await expect(insert()).rejects.toThrow(/member_invites_one_available_per_member_idx/);
    });

    it('CA-07 rolls everything back when the write fails after the revocation', async () => {
      const family = await seedFamily();
      const failing = useCase({
        insertInvite: async () => {
          throw new Error('connection lost');
        },
      });
      await expect(
        failing.execute({ actor: adminOf(family), memberId: family.guestId, requestId: 'r7' }),
      ).rejects.toMatchObject({ code: 'DEPENDENCY_UNAVAILABLE' });

      expect(await invitesOf(family.guestId)).toHaveLength(0);
      expect(
        (
          await container.dbPool.query('select revoked_at from app.sessions where id = $1', [
            family.guestSessionId,
          ])
        ).rows[0]?.revoked_at,
      ).toBeNull();
    });
  },
);
