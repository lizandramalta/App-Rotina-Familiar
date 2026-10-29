/** SPEC-015 Fase 1 / SCRUM-80: catálogo, isolamento e unicidade em PostgreSQL real. */
import { createHash, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { buildHttpApp } from '../../src/presentation/http/app.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const NOW = new Date('2026-10-20T12:00:00.000Z');

interface FamilyFixture {
  readonly familyId: string;
  readonly admin: ActorContext;
  readonly member: ActorContext;
  readonly kids: ActorContext;
  readonly adminToken: string;
  readonly memberToken: string;
  readonly kidsToken: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Reward items persistence — SPEC-015 phase 1',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const families: FamilyFixture[] = [];

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath))
        loadDotenv({ path: envPath });
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of families) {
          await container.dbPool.query('delete from app.reward_items where family_id = $1', [
            family.familyId,
          ]);
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
        await container.dispose();
      }
    });

    async function seedFamily(): Promise<FamilyFixture> {
      const familyId = randomUUID();
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [familyId, NOW],
      );
      const actors = [];
      const tokens: string[] = [];
      for (const [role, isFamilyCreator] of [
        [MemberRole.ADMINISTRATOR, true],
        [MemberRole.MEMBER, false],
        [MemberRole.KIDS, false],
      ] as const) {
        const memberId = randomUUID();
        const sessionId = randomUUID();
        await container.dbPool.query(
          `insert into app.members
            (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, $3, $4, 'Pessoa de teste', $5, $5)`,
          [memberId, familyId, role, isFamilyCreator, NOW],
        );
        await container.dbPool.query(
          `insert into app.sessions
            (id, family_id, member_id, refresh_token_hash, installation_proof_hash, created_at, last_seen_at)
           values ($1, $2, $3, $4, $5, $6, $6)`,
          [sessionId, familyId, memberId, randomUUID(), randomUUID(), NOW],
        );
        const token = randomUUID();
        await container.dbPool.query(
          `insert into app.session_access_tokens
            (id, session_id, token_hash, expires_at, created_at)
           values ($1, $2, $3, $4, $5)`,
          [
            randomUUID(),
            sessionId,
            createHash('sha256').update(token).digest('hex'),
            new Date('2099-01-01T00:00:00Z'),
            NOW,
          ],
        );
        actors.push({ sessionId, familyId, memberId, role, isFamilyCreator });
        tokens.push(token);
      }
      const fixture = {
        familyId,
        admin: actors[0]!,
        member: actors[1]!,
        kids: actors[2]!,
        adminToken: tokens[0]!,
        memberToken: tokens[1]!,
        kidsToken: tokens[2]!,
      };
      families.push(fixture);
      return fixture;
    }

    it('CA-01/CA-02/CA-06 returns the six ordered defaults and only own custom items', async () => {
      const familyA = await seedFamily();
      const familyB = await seedFamily();
      const created = await container.addRewardItemUseCase.execute({
        actor: familyA.admin,
        title: '  Noite de pizza  ',
        details: 'Escolher juntos',
      });
      const own = await container.listRewardItemsUseCase.execute(familyA.admin);
      const other = await container.listRewardItemsUseCase.execute(familyB.admin);
      expect(own.predefined.map((item) => item.title)).toEqual([
        'Escolher o filme da noite',
        'Escolher o jantar em família',
        'Noite de jogos em família',
        'Sobremesa especial',
        'Piquenique ou passeio no parque',
        'Escolher uma atividade em família',
      ]);
      expect(own.custom).toEqual([created]);
      expect(other.custom).toEqual([]);
      expect(other.predefined).toEqual(own.predefined);
      const missionLinks = await container.dbPool.query<{ total: string }>(
        'select count(*)::text as total from app.missions where family_id = $1',
        [familyA.familyId],
      );
      expect(missionLinks.rows[0]?.total).toBe('0');
    });

    it('CA-04/CA-07 makes concurrent normalized inserts yield one item and a stable duplicate error', async () => {
      const family = await seedFamily();
      const requests = [
        { actor: family.admin, title: '  Noite de pizza ', details: undefined },
        { actor: family.admin, title: 'noite DE PIZZA', details: undefined },
      ];
      const outcomes = await Promise.allSettled(
        requests.map((request) => container.addRewardItemUseCase.execute(request)),
      );
      expect(outcomes.filter((outcome) => outcome.status === 'fulfilled')).toHaveLength(1);
      expect(outcomes.filter((outcome) => outcome.status === 'rejected')).toHaveLength(1);
      const rejected = outcomes.find((outcome) => outcome.status === 'rejected');
      expect(rejected).toMatchObject({
        reason: { code: 'REWARD_TITLE_ALREADY_EXISTS', statusCode: 422 },
      });
      const catalog = await container.listRewardItemsUseCase.execute(family.admin);
      expect(catalog.custom).toHaveLength(1);
      await expect(container.addRewardItemUseCase.execute(requests[0]!)).rejects.toMatchObject({
        code: 'REWARD_TITLE_ALREADY_EXISTS',
      });
    });

    it('CA-05 denies member and Kids even with valid sessions', async () => {
      const family = await seedFamily();
      for (const actor of [family.member, family.kids]) {
        await expect(container.listRewardItemsUseCase.execute(actor)).rejects.toMatchObject({
          code: 'INSUFFICIENT_PERMISSIONS',
          statusCode: 403,
        });
        await expect(
          container.addRewardItemUseCase.execute({ actor, title: 'Pizza', details: undefined }),
        ).rejects.toMatchObject({ code: 'INSUFFICIENT_PERMISSIONS', statusCode: 403 });
      }
    });

    it('CA-05 rejects a session revoked before entering the family lock', async () => {
      const family = await seedFamily();
      await container.dbPool.query('update app.sessions set revoked_at = $2 where id = $1', [
        family.admin.sessionId,
        NOW,
      ]);
      await expect(
        container.addRewardItemUseCase.execute({
          actor: family.admin,
          title: 'Pizza',
          details: undefined,
        }),
      ).rejects.toMatchObject({ code: 'SESSION_REVOKED' });
      const rows = await container.dbPool.query(
        'select id from app.reward_items where family_id = $1',
        [family.familyId],
      );
      expect(rows.rowCount).toBe(0);
    });

    it('CA-01–CA-06 serves the real authenticated HTTP flow with family isolation', async () => {
      const familyA = await seedFamily();
      const familyB = await seedFamily();
      const app = buildHttpApp(container, container.config);
      const auth = (token: string) => ({ authorization: `Bearer ${token}` });
      try {
        const unauthenticated = await app.inject({ method: 'GET', url: '/v1/reward-items' });
        expect(unauthenticated.statusCode).toBe(401);

        const created = await app.inject({
          method: 'POST',
          url: '/v1/reward-items',
          headers: auth(familyA.adminToken),
          payload: { title: '  Pizza da família  ', details: 'Escolher juntos' },
        });
        expect(created.statusCode).toBe(201);
        expect(created.json()).toMatchObject({
          title: 'Pizza da família',
          details: 'Escolher juntos',
          source: 'custom',
        });

        const own = await app.inject({
          method: 'GET',
          url: '/v1/reward-items',
          headers: auth(familyA.adminToken),
        });
        const other = await app.inject({
          method: 'GET',
          url: '/v1/reward-items',
          headers: auth(familyB.adminToken),
        });
        expect(own.json().predefined).toHaveLength(6);
        expect(own.json().custom).toHaveLength(1);
        expect(other.json().predefined).toHaveLength(6);
        expect(other.json().custom).toHaveLength(0);

        const duplicate = await app.inject({
          method: 'POST',
          url: '/v1/reward-items',
          headers: auth(familyA.adminToken),
          payload: { title: 'pizza DA FAMÍLIA' },
        });
        expect(duplicate.statusCode).toBe(422);
        expect(duplicate.json().code).toBe('REWARD_TITLE_ALREADY_EXISTS');

        const invalid = await app.inject({
          method: 'POST',
          url: '/v1/reward-items',
          headers: auth(familyA.adminToken),
          payload: { title: '  ' },
        });
        expect(invalid.statusCode).toBe(422);
        expect(invalid.json().fieldErrors.title).toContain('REWARD_TITLE_REQUIRED');

        const forgedFamily = await app.inject({
          method: 'GET',
          url: `/v1/reward-items?familyId=${familyB.familyId}`,
          headers: auth(familyA.adminToken),
        });
        expect(forgedFamily.statusCode).toBe(400);
        expect(forgedFamily.json().code).toBe('UNKNOWN_FIELD');

        for (const token of [familyA.memberToken, familyA.kidsToken]) {
          const denied = await app.inject({
            method: 'GET',
            url: '/v1/reward-items',
            headers: auth(token),
          });
          expect(denied.statusCode).toBe(403);
          expect(denied.json().code).toBe('INSUFFICIENT_PERMISSIONS');
        }

        const docs = await app.inject({ method: 'GET', url: '/docs/json' });
        expect(docs.statusCode).toBe(200);
        expect(docs.json().paths['/v1/reward-items'].post.security).toEqual([{ bearerAuth: [] }]);
      } finally {
        await app.close();
      }
    });
  },
);
