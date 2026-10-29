/** SPEC-009 CA-14/15: persistence, family isolation, repeatability and inbox dismissal. */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { FamilyApplauseService } from '../../src/modules/family/infrastructure/family-applause-service.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family applause persistence',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    let service: FamilyApplauseService;
    const familyIds: string[] = [];

    beforeAll(() => {
      container = createContainer(loadConfiguration());
      service = new FamilyApplauseService(container.dbPool);
    });

    afterAll(async () => {
      if (!container) return;
      for (const id of familyIds) {
        await container.dbPool.query(
          `delete from app.family_applause_push_outbox where applause_id in (
            select id from app.family_applause where family_id = $1
          )`,
          [id],
        );
        await container.dbPool.query('delete from app.family_applause where family_id = $1', [id]);
        await container.dbPool.query('delete from app.families where id = $1', [id]);
      }
      await container.dispose();
    });

    async function seedFamily() {
      const familyId = randomUUID();
      const adminId = randomUUID();
      const secondAdminId = randomUUID();
      const kidId = randomUUID();
      const kidSessionId = randomUUID();
      familyIds.push(familyId);
      await container.dbPool.query(
        `insert into app.families (id, name, timezone) values ($1, 'Casa', 'America/Sao_Paulo')`,
        [familyId],
      );
      for (const [id, role, name] of [
        [adminId, 'administrator', 'Alex'],
        [secondAdminId, 'administrator', 'Sam'],
        [kidId, 'kids', 'Jô'],
      ]) {
        await container.dbPool.query(
          `insert into app.members (id, family_id, role, display_name) values ($1, $2, $3, $4)`,
          [id, familyId, role, name],
        );
      }
      await container.dbPool.query(
        `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
       values ($1, $2, $3, $4, 'test-proof')`,
        [kidSessionId, familyId, kidId, randomUUID()],
      );
      const actor = (
        memberId: string,
        role: MemberRole,
        sessionId = randomUUID(),
      ): ActorContext => ({
        familyId,
        memberId,
        role,
        sessionId,
        isFamilyCreator: false,
      });
      return {
        familyId,
        kidId,
        alex: actor(adminId, MemberRole.ADMINISTRATOR),
        sam: actor(secondAdminId, MemberRole.ADMINISTRATOR),
        kid: actor(kidId, MemberRole.KIDS, kidSessionId),
      };
    }

    it('groups senders, keeps repeated events, hides dismissed messages and isolates families', async () => {
      const first = await seedFamily();
      const other = await seedFamily();
      await service.registerDevice(first.kid, 'a'.repeat(64), 'development');
      await service.send(first.alex, first.kidId, '2026-10-19', '2026-10-25');
      await service.send(first.alex, first.kidId, '2026-10-19', '2026-10-25');
      await service.send(first.sam, first.kidId, '2026-10-19', '2026-10-25');

      const stored = await container.dbPool.query(
        'select count(*)::integer as count from app.family_applause where family_id = $1',
        [first.familyId],
      );
      expect(stored.rows[0]?.count).toBe(3);
      const outbox = await container.dbPool.query(
        `select count(*)::integer as count from app.family_applause_push_outbox o
       join app.family_applause a on a.id = o.applause_id where a.family_id = $1`,
        [first.familyId],
      );
      expect(outbox.rows[0]?.count).toBe(3);
      expect((await service.summary(first.alex, '2026-10-19', '2026-10-25')).items).toEqual([
        { memberId: first.kidId, count: 2, sentByMe: true },
      ]);
      const inbox = await service.received(first.kid);
      expect(inbox.items).toHaveLength(1);
      expect(inbox.items[0]?.senderNames).toEqual(['Alex', 'Sam']);
      await expect(service.dismiss(other.kid, inbox.items[0]!.id)).rejects.toMatchObject({
        code: 'RESOURCE_NOT_FOUND',
      });
      await service.dismiss(first.kid, inbox.items[0]!.id);
      expect((await service.received(first.kid)).items).toEqual([]);
      await service.send(first.alex, first.kidId, '2026-10-19', '2026-10-25');
      expect((await service.received(first.kid)).items).toHaveLength(1);
      await expect(
        service.send(first.alex, other.kidId, '2026-10-19', '2026-10-25'),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
      await expect(
        service.send(first.kid, first.alex.memberId, '2026-10-19', '2026-10-25'),
      ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
    });
  },
);
