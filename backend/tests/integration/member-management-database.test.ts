/**
 * Persistência de membros em PostgreSQL real (SPEC-003 Fase 1).
 *
 * Valida o que os dublês unitários não cobrem: escopo por família, ordenação
 * estável do cursor, tamanho de página e a inserção sem sessão ou convite.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import {
  CreateMemberUseCase,
  GetMemberDetailUseCase,
  ListFamilyMembersUseCase,
  MEMBERS_PAGE_SIZE,
} from '../../src/modules/family/application/member-management-use-cases.js';
import { PostgresMemberManagementRepository } from '../../src/modules/family/infrastructure/postgres-member-management-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

const INTEGRATION_TIMEOUT_MS = 60_000;
const NOW = new Date('2026-10-08T15:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly adminId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Member management persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    const repository = new PostgresMemberManagementRepository();
    const seededFamilies: SeededFamily[] = [];
    const clock: Clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of seededFamilies) {
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
      }
      await container?.dispose();
    });

    async function seedFamily(memberCount = 1): Promise<SeededFamily> {
      const family: SeededFamily = { familyId: randomUUID(), adminId: randomUUID() };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $2, 'administrator', true, 'Admin', $3, $3)`,
        [family.adminId, family.familyId, NOW],
      );
      for (let index = 1; index < memberCount; index += 1) {
        const createdAt = new Date(NOW.getTime() + index * 1000);
        await container.dbPool.query(
          `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, 'member', false, $3, $4, $4)`,
          [randomUUID(), family.familyId, `Member ${index}`, createdAt],
        );
      }
      seededFamilies.push(family);
      return family;
    }

    function actorOf(family: SeededFamily): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId: family.adminId,
        role: MemberRole.ADMINISTRATOR,
        isFamilyCreator: true,
      };
    }

    it('persists a created member only in the actor family and never creates a session or invitation', async () => {
      const family = await seedFamily();
      const result = await new CreateMemberUseCase({
        repository,
        transactionRunner: container.transactionRunner,
        clock,
      }).execute({ actor: actorOf(family), name: ' Marina ', role: MemberRole.KIDS });

      expect(result).toMatchObject({
        name: 'Marina',
        role: MemberRole.KIDS,
        isFamilyCreator: false,
      });
      const persisted = await container.dbPool.query(
        'select family_id, role from app.members where id = $1',
        [result.id],
      );
      expect(persisted.rows).toEqual([{ family_id: family.familyId, role: MemberRole.KIDS }]);
      expect(
        (
          await container.dbPool.query('select 1 from app.sessions where member_id = $1', [
            result.id,
          ])
        ).rowCount,
      ).toBe(0);
    });

    it('uses a stable, family-scoped cursor with no more than twenty items per page', async () => {
      const family = await seedFamily(MEMBERS_PAGE_SIZE + 2);
      const useCase = new ListFamilyMembersUseCase({
        repository,
        transactionRunner: container.transactionRunner,
      });
      const first = await useCase.execute(actorOf(family), undefined);
      const second = await useCase.execute(actorOf(family), first.nextCursor ?? undefined);

      expect(first.items).toHaveLength(MEMBERS_PAGE_SIZE);
      expect(first.nextCursor).toEqual(expect.any(String));
      expect(second.items).toHaveLength(2);
      expect(second.nextCursor).toBeNull();

      const foreignFamily = await seedFamily();
      await expect(
        new GetMemberDetailUseCase({
          repository,
          transactionRunner: container.transactionRunner,
        }).execute(actorOf(foreignFamily), first.items[0]?.id ?? ''),
      ).rejects.toMatchObject({ code: 'RESOURCE_NOT_FOUND' });
    });
  },
);
