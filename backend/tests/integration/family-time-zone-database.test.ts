/**
 * Mudança de fuso contra PostgreSQL real (SPEC-002 Fase 3: CA-05 a CA-08).
 *
 * Prova o que o dublê em memória não prova: lock por família, constraints,
 * prévia sem escrita, ciclos encerrados intactos, isolamento entre famílias e
 * ausência de privilégio público. Desligado por padrão; use `RUN_INTEGRATION_TESTS=1`.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { ChangeFamilyTimeZoneUseCase } from '../../src/modules/family/application/change-family-time-zone-use-case.js';
import { GetFamilySettingsUseCase } from '../../src/modules/family/application/get-family-settings-use-case.js';
import { PreviewFamilyTimeZoneChangeUseCase } from '../../src/modules/family/application/preview-family-time-zone-change-use-case.js';
import { PostgresFamilySettingsRepository } from '../../src/modules/family/infrastructure/postgres-family-settings-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { ActionNotAllowedError } from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const INTEGRATION_TIMEOUT_MS = 60_000;
const SP = 'America/Sao_Paulo';
const TOKYO = 'Asia/Tokyo';

interface SeededFamily {
  familyId: string;
  adminId: string;
  memberId: string;
  kidId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family time zone persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    const { logger } = createRecordingLogger();
    const repository = new PostgresFamilySettingsRepository();
    const seeded: SeededFamily[] = [];

    let now = new Date('2026-10-08T15:00:00.000Z'); // quinta 12:00 em SP
    const clock: Clock = { now: () => now, nowIsoString: () => now.toISOString() };
    const crypto = { newId: () => randomUUID() };

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
          await container.dbPool.query(`delete from app.families where id = $1`, [family.familyId]);
        }
      }
      await container?.dispose();
    });

    const useCases = () => {
      const deps = { repository, transactionRunner: container.transactionRunner, clock, logger };
      return {
        get: new GetFamilySettingsUseCase({ ...deps, crypto }),
        preview: new PreviewFamilyTimeZoneChangeUseCase(deps),
        change: new ChangeFamilyTimeZoneUseCase({ ...deps, crypto }),
      };
    };

    /** Família com Admin, Membro e Kids e um ciclo aberto de quarta a segunda. */
    async function seedFamily(): Promise<SeededFamily> {
      const family: SeededFamily = {
        familyId: randomUUID(),
        adminId: randomUUID(),
        memberId: randomUUID(),
        kidId: randomUUID(),
      };
      const pool = container.dbPool;

      await pool.query(`insert into app.families (id, name, timezone) values ($1, 'Casa', $2)`, [
        family.familyId,
        SP,
      ]);
      for (const [id, role, creator] of [
        [family.adminId, 'administrator', true],
        [family.memberId, 'member', false],
        [family.kidId, 'kids', false],
      ] as const) {
        await pool.query(
          `insert into app.members (id, family_id, role, is_family_creator, display_name)
           values ($1, $2, $3, $4, 'Pessoa')`,
          [id, family.familyId, role, creator],
        );
      }
      await pool.query(
        `insert into app.weekly_cycles (id, family_id, starts_at, ends_at, time_zone, reference_week)
         values ($1, $2, '2026-10-07T15:00:00Z', '2026-10-12T03:00:00Z', $3, '2026-10-05')`,
        [randomUUID(), family.familyId, SP],
      );

      seeded.push(family);
      return family;
    }

    const actorOf = (family: SeededFamily, role: ActorContext['role'], memberId: string) =>
      ({
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId,
        role,
        isFamilyCreator: role === MemberRole.ADMINISTRATOR,
      }) satisfies ActorContext;

    const adminOf = (family: SeededFamily) =>
      actorOf(family, MemberRole.ADMINISTRATOR, family.adminId);

    const snapshot = async (familyId: string) => {
      const pool = container.dbPool;
      return {
        family: (await pool.query(`select timezone from app.families where id = $1`, [familyId]))
          .rows,
        cycles: (
          await pool.query(
            `select starts_at, ends_at, time_zone, in_transition from app.weekly_cycles
              where family_id = $1 order by starts_at`,
            [familyId],
          )
        ).rows,
        changes: (
          await pool.query(
            `select to_time_zone, status from app.family_time_zone_changes
              where family_id = $1 order by requested_at`,
            [familyId],
          )
        ).rows,
      };
    };

    describe('CA-05: only Administrators', () => {
      it('refuses Member and Kids and leaves the database untouched', async () => {
        const family = await seedFamily();
        const before = await snapshot(family.familyId);
        const body = { timeZoneId: TOKYO, application: 'immediate' };

        for (const actor of [
          actorOf(family, MemberRole.MEMBER, family.memberId),
          actorOf(family, MemberRole.KIDS, family.kidId),
        ]) {
          await expect(useCases().get.execute({ actor })).rejects.toBeInstanceOf(
            ActionNotAllowedError,
          );
          await expect(useCases().change.execute({ actor, ...body })).rejects.toBeInstanceOf(
            ActionNotAllowedError,
          );
        }

        expect(await snapshot(family.familyId)).toEqual(before);
      });

      it('trusts the database role over a stale session role', async () => {
        const family = await seedFamily();
        await container.dbPool.query(`update app.members set role = 'member' where id = $1`, [
          family.adminId,
        ]);

        await expect(
          useCases().change.execute({
            actor: adminOf(family),
            timeZoneId: TOKYO,
            application: 'immediate',
          }),
        ).rejects.toBeInstanceOf(ActionNotAllowedError);
        expect((await snapshot(family.familyId)).changes).toEqual([]);
      });

      it('never lets an Administrator read or change another family', async () => {
        const mine = await seedFamily();
        const other = await seedFamily();
        const before = await snapshot(other.familyId);

        // Sessão de `mine` com o memberId de `other`: a consulta é escopada pela
        // família da sessão e o membro não existe nela.
        await expect(
          useCases().change.execute({
            actor: { ...adminOf(mine), memberId: other.adminId },
            timeZoneId: TOKYO,
            application: 'immediate',
          }),
        ).rejects.toThrow();

        expect(await snapshot(other.familyId)).toEqual(before);
      });
    });

    describe('CA-06/CA-07: preview does not write', () => {
      it('leaves every table untouched, even when the cycle has expired', async () => {
        const family = await seedFamily();
        const before = await snapshot(family.familyId);
        now = new Date('2026-10-30T15:00:00.000Z');

        try {
          const preview = await useCases().preview.execute({
            actor: adminOf(family),
            timeZoneId: TOKYO,
            application: 'nextCycle',
          });

          expect(preview.isTransition).toBe(true);
          expect(await snapshot(family.familyId)).toEqual(before);
        } finally {
          now = new Date('2026-10-08T15:00:00.000Z');
        }
      });
    });

    describe('CA-06: immediate application', () => {
      it('keeps the cycle start and moves its end to the next Monday 00:00 in the new zone', async () => {
        const family = await seedFamily();

        const result = await useCases().change.execute({
          actor: adminOf(family),
          timeZoneId: TOKYO,
          application: 'immediate',
        });

        expect(result.timeZoneId).toBe(TOKYO);
        const after = await snapshot(family.familyId);
        expect(after.family).toEqual([{ timezone: TOKYO }]);
        expect(after.cycles).toEqual([
          {
            starts_at: new Date('2026-10-07T15:00:00.000Z'),
            ends_at: new Date('2026-10-11T15:00:00.000Z'), // segunda 00:00 em Tóquio
            time_zone: TOKYO,
            in_transition: true,
          },
        ]);
        expect(after.changes).toEqual([{ to_time_zone: TOKYO, status: 'APPLIED' }]);
      });
    });

    describe('CA-07: next cycle application', () => {
      it('keeps the zone and cycle, schedules the change and applies it when the cycle ends', async () => {
        const family = await seedFamily();
        const actor = adminOf(family);

        const confirmed = await useCases().change.execute({
          actor,
          timeZoneId: TOKYO,
          application: 'nextCycle',
        });
        expect(confirmed.timeZoneId).toBe(SP);
        expect(confirmed.scheduledTimeZoneChange).toEqual({
          timeZoneId: TOKYO,
          effectiveAt: '2026-10-12T03:00:00.000Z',
        });
        expect((await snapshot(family.familyId)).family).toEqual([{ timezone: SP }]);

        now = new Date('2026-10-14T15:00:00.000Z');
        try {
          const settings = await useCases().get.execute({ actor });

          expect(settings.timeZoneId).toBe(TOKYO);
          expect(settings.scheduledTimeZoneChange).toBeNull();
          expect(settings.limits).toMatchObject({
            startsAt: '2026-10-12T03:00:00.000Z',
            endsAt: '2026-10-18T15:00:00.000Z',
            timeZoneId: TOKYO,
            isTransition: true,
          });
          const after = await snapshot(family.familyId);
          expect(after.family).toEqual([{ timezone: TOKYO }]);
          expect(after.changes).toEqual([{ to_time_zone: TOKYO, status: 'APPLIED' }]);
        } finally {
          now = new Date('2026-10-08T15:00:00.000Z');
        }
      });

      it('replaces the scheduled change with the latest request', async () => {
        const family = await seedFamily();
        const actor = adminOf(family);

        await useCases().change.execute({ actor, timeZoneId: TOKYO, application: 'nextCycle' });
        await useCases().change.execute({
          actor,
          timeZoneId: 'America/Manaus',
          application: 'nextCycle',
        });

        expect((await snapshot(family.familyId)).changes).toEqual([
          { to_time_zone: TOKYO, status: 'SUPERSEDED' },
          { to_time_zone: 'America/Manaus', status: 'SCHEDULED' },
        ]);
      });
    });

    describe('CA-08: history is preserved', () => {
      it('leaves ended cycles exactly as they were and only touches the open one', async () => {
        const family = await seedFamily();
        // Um ciclo encerrado antes do aberto, com fuso e limites próprios.
        await container.dbPool.query(
          `insert into app.weekly_cycles (id, family_id, starts_at, ends_at, time_zone, reference_week)
           values ($1, $2, '2026-09-28T03:00:00Z', '2026-10-05T03:00:00Z', $3, '2026-09-28'),
                  ($4, $2, '2026-10-05T03:00:00Z', '2026-10-07T15:00:00Z', $3, '2026-10-05')`,
          [randomUUID(), family.familyId, SP, randomUUID()],
        );
        const before = (await snapshot(family.familyId)).cycles.slice(0, 2);

        await useCases().change.execute({
          actor: adminOf(family),
          timeZoneId: TOKYO,
          application: 'immediate',
        });

        const after = (await snapshot(family.familyId)).cycles;
        expect(after.slice(0, 2)).toEqual(before);
        expect(after.at(-1)).toMatchObject({ time_zone: TOKYO, in_transition: true });
      });

      it('does not touch another family', async () => {
        const mine = await seedFamily();
        const other = await seedFamily();
        const before = await snapshot(other.familyId);

        await useCases().change.execute({
          actor: adminOf(mine),
          timeZoneId: TOKYO,
          application: 'immediate',
        });

        expect(await snapshot(other.familyId)).toEqual(before);
      });
    });

    describe('concurrency (BA-08)', () => {
      it('serializes two confirmations for the same family: one scheduled change survives', async () => {
        const family = await seedFamily();
        const actor = adminOf(family);

        const outcomes = await Promise.allSettled([
          useCases().change.execute({ actor, timeZoneId: TOKYO, application: 'nextCycle' }),
          useCases().change.execute({
            actor,
            timeZoneId: 'America/Manaus',
            application: 'nextCycle',
          }),
        ]);

        expect(outcomes.every((outcome) => outcome.status === 'fulfilled')).toBe(true);
        const { changes } = await snapshot(family.familyId);
        expect(changes.filter((change) => change.status === 'SCHEDULED')).toHaveLength(1);
        expect(changes.filter((change) => change.status === 'SUPERSEDED')).toHaveLength(1);
      });

      it('settles an expired cycle once when reads race', async () => {
        const family = await seedFamily();
        now = new Date('2026-10-20T15:00:00.000Z');
        try {
          await Promise.all([
            useCases().get.execute({ actor: adminOf(family) }),
            useCases().get.execute({ actor: adminOf(family) }),
          ]);

          const { cycles } = await snapshot(family.familyId);
          expect(cycles).toHaveLength(3);
          for (let index = 1; index < cycles.length; index += 1) {
            expect(cycles[index]?.starts_at).toEqual(cycles[index - 1]?.ends_at);
          }
        } finally {
          now = new Date('2026-10-08T15:00:00.000Z');
        }
      });
    });

    describe('database invariants of migration 0005', () => {
      it('grants no privilege on the new table to anon or authenticated (BA-19)', async () => {
        const result = await container.dbPool.query(
          `select grantee from information_schema.role_table_grants
            where table_schema = 'app'
              and table_name = 'family_time_zone_changes'
              and grantee in ('anon', 'authenticated')`,
        );

        expect(result.rows).toEqual([]);
      });

      it('refuses a second SCHEDULED change for the same family', async () => {
        const family = await seedFamily();
        const insert = () =>
          container.dbPool.query(
            `insert into app.family_time_zone_changes
               (id, family_id, requested_by_member_id, from_time_zone, to_time_zone,
                application, status, effective_at, requested_at)
             values ($1, $2, $3, $4, $5, 'NEXT_CYCLE', 'SCHEDULED', now(), now())`,
            [randomUUID(), family.familyId, family.adminId, SP, TOKYO],
          );

        await insert();
        await expect(insert()).rejects.toThrow(/one_scheduled/);
      });

      it('refuses a change requested by a member of another family', async () => {
        const mine = await seedFamily();
        const other = await seedFamily();

        await expect(
          container.dbPool.query(
            `insert into app.family_time_zone_changes
               (id, family_id, requested_by_member_id, from_time_zone, to_time_zone,
                application, status, effective_at, requested_at)
             values ($1, $2, $3, $4, $5, 'IMMEDIATE', 'APPLIED', now(), now())`,
            [randomUUID(), mine.familyId, other.adminId, SP, TOKYO],
          ),
        ).rejects.toThrow();
      });
    });
  },
);
