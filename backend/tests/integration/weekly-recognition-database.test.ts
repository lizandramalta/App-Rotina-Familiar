/** SPEC-020 Fase 1 / SCRUM-102 CA-01–06: PostgreSQL real, sem envio externo. */
import { randomUUID } from 'node:crypto';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { PostgresRecognitionRepository } from '../../src/modules/recognition/infrastructure/postgres-recognition-repository.js';
import { PostgresFamilySettingsRepository } from '../../src/modules/family/infrastructure/postgres-family-settings-repository.js';
import { FinalizeWeeklyHighlight } from '../../src/modules/recognition/application/finalize-weekly-highlight.js';
import { WeeklyHighlightWorker } from '../../src/modules/recognition/infrastructure/weekly-highlight-worker.js';
import { RecognitionPushWorker } from '../../src/modules/recognition/infrastructure/recognition-push-worker.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const START = '2026-10-19T03:00:00.000Z';
const END = '2026-10-26T03:00:00.000Z';
const INSIDE = '2026-10-22T12:00:00.000Z';

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'SPEC-020 weekly recognition persistence',
  { timeout: 30_000 },
  () => {
    let container: ApplicationContainer;
    const families: string[] = [];
    const { logger } = createRecordingLogger();
    beforeAll(() => {
      container = createContainer(loadConfiguration());
    });
    afterAll(() => container?.dispose());
    afterEach(async () => {
      for (const familyId of families.splice(0)) {
        const db = container.dbPool;
        await db.query('delete from app.weekly_highlights where family_id = $1', [familyId]);
        await db.query('delete from app.task_events where family_id = $1', [familyId]);
        await db.query('delete from app.completion_credits where family_id = $1', [familyId]);
        await db.query('delete from app.completions where family_id = $1', [familyId]);
        await db.query('delete from app.task_assignees where family_id = $1', [familyId]);
        await db.query('delete from app.task_occurrences where family_id = $1', [familyId]);
        await db.query('delete from app.task_templates where family_id = $1', [familyId]);
        await db.query('delete from app.families where id = $1', [familyId]);
      }
    });

    async function seedFamily() {
      const familyId = randomUUID();
      families.push(familyId);
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at) values ($1, 'Recognition test', 'America/Sao_Paulo', $2)`,
        [familyId, START],
      );
      const actors: ActorContext[] = [];
      for (const role of ['administrator', 'member', 'kids'] as const) {
        const memberId = randomUUID();
        const sessionId = randomUUID();
        await container.dbPool.query(
          `insert into app.members (id, family_id, role, display_name) values ($1,$2,$3,'Test person')`,
          [memberId, familyId, role],
        );
        await container.dbPool.query(
          `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash) values ($1,$2,$3,$4,'test-proof')`,
          [sessionId, familyId, memberId, randomUUID()],
        );
        actors.push({ familyId, memberId, sessionId, role, isFamilyCreator: false });
      }
      const cycleId = randomUUID();
      await container.dbPool.query(
        `insert into app.weekly_cycles (id,family_id,starts_at,ends_at,time_zone,reference_week) values ($1,$2,$3,$4,'America/Sao_Paulo','2026-10-19')`,
        [cycleId, familyId, START, END],
      );
      return { familyId, cycleId, admin: actors[0]!, member: actors[1]!, kid: actors[2]! };
    }
    type Family = Awaited<ReturnType<typeof seedFamily>>;
    async function credit(
      family: Family,
      members: readonly ActorContext[],
      weight = 3,
      at = INSIDE,
    ) {
      const created = await container.createTaskUseCase.execute({
        actor: family.admin,
        title: 'Test task',
        weight,
        scheduledDate: '2026-10-22',
        assigneeIds: members.map((m) => m.memberId),
        note: null,
      });
      await container.completeTaskUseCase.execute(family.admin, created.id);
      await container.dbPool.query(
        'update app.completions set completed_at = $2 where task_id = $1',
        [created.id, at],
      );
      return created.id;
    }
    async function highlights(family: Family) {
      return (
        await container.dbPool.query(
          'select * from app.weekly_highlights where family_id = $1 order by starts_at',
          [family.familyId],
        )
      ).rows;
    }
    async function deliveries(family: Family) {
      return (
        await container.dbPool.query(
          `select d.* from app.recognition_notification_deliveries d
      join app.weekly_recognitions r on r.id = d.recognition_id where r.family_id = $1`,
          [family.familyId],
        )
      ).rows;
    }
    async function recognize() {
      const family = await seedFamily();
      await credit(family, [family.kid]);
      await container.finalizeWeeklyHighlight.execute(family.familyId);
      const recognition = (await container.ownWeeklyRecognitions.list(family.kid)).items[0]!;
      return { family, recognition };
    }
    async function device(actor: ActorContext, environment = 'development') {
      const id = randomUUID();
      await container.dbPool.query(
        `insert into app.push_devices (id,session_id,device_token,environment) values ($1,$2,$3,$4)`,
        [id, actor.sessionId, 'a'.repeat(64), environment],
      );
      return id;
    }
    async function makeDue(id: string) {
      await container.dbPool.query(
        `update app.recognition_notification_deliveries set available_at = now() - interval '1 second' where recognition_id = $1`,
        [id],
      );
    }

    it('CA-01/02/03/04 finalizes tied adults/Kids once under concurrent execution and preserves the snapshot after corrections', async () => {
      const f = await seedFamily();
      const task = await credit(f, [f.member, f.kid]);
      await Promise.all([
        container.finalizeWeeklyHighlight.execute(f.familyId),
        container.finalizeWeeklyHighlight.execute(f.familyId),
      ]);
      const before = (await container.ownWeeklyRecognitions.list(f.kid)).items;
      expect(before).toHaveLength(1);
      expect(before[0]).toMatchObject({
        points: 3,
        completedTasks: 1,
        isTie: true,
        openedAt: null,
        period: { startsAt: START, endsAt: END },
      });
      expect((await container.ownWeeklyRecognitions.list(f.admin)).items).toEqual([]);
      expect((await highlights(f)).filter((h) => h.cycle_id === f.cycleId)).toHaveLength(1);
      expect(await deliveries(f)).toHaveLength(2);
      await container.editTaskUseCase.execute({
        actor: f.admin,
        taskId: task,
        title: undefined,
        weight: 1,
        scheduledDate: undefined,
        assigneeIds: undefined,
        note: undefined,
        signalResolution: undefined,
      });
      await container.reopenTaskUseCase.execute(f.admin, task, false);
      await container.finalizeWeeklyHighlight.execute(f.familyId);
      expect((await container.ownWeeklyRecognitions.list(f.kid)).items).toEqual(before);
      expect(await deliveries(f)).toHaveLength(2);
    });

    it('CA-01/02 uses inclusive start/exclusive end and ignores undone credits and removed members', async () => {
      const f = await seedFamily();
      await credit(f, [f.kid], 2, START);
      await credit(f, [f.member], 3, END);
      const undone = await credit(f, [f.member], 3);
      await container.reopenTaskUseCase.execute(f.admin, undone, false);
      await credit(f, [f.admin], 3);
      await container.dbPool.query('update app.members set removed_at = now() where id = $1', [
        f.admin.memberId,
      ]);
      await container.finalizeWeeklyHighlight.execute(f.familyId);
      const kid = (await container.ownWeeklyRecognitions.list(f.kid)).items;
      expect(kid).toHaveLength(1);
      expect(kid[0]).toMatchObject({ points: 2, completedTasks: 1, isTie: false });
      const member = (await container.ownWeeklyRecognitions.list(f.member)).items;
      expect(member[0]?.period.startsAt).toBe(END);
    });

    it('CA-02 records an empty final result for pending or awaiting-confirmation tasks', async () => {
      const f = await seedFamily();
      const task = await container.createTaskUseCase.execute({
        actor: f.admin,
        title: 'Pending kid task',
        weight: 3,
        scheduledDate: '2026-10-22',
        assigneeIds: [f.kid.memberId],
        note: null,
      });
      await container.dbPool.query(
        "update app.task_occurrences set status = 'awaitingConfirmation' where id = $1",
        [task.id],
      );
      await container.finalizeWeeklyHighlight.execute(f.familyId);
      expect((await highlights(f))[0]?.winner_count).toBe(0);
      expect(await deliveries(f)).toEqual([]);
      expect((await container.ownWeeklyRecognitions.list(f.kid)).items).toEqual([]);
    });

    it('CA-03 rolls back result and outbox together and recovers the same cycle', async () => {
      const f = await seedFamily();
      await credit(f, [f.kid]);
      class FailingRepository extends PostgresRecognitionRepository {
        override async saveFinalResult(
          ...args: Parameters<PostgresRecognitionRepository['saveFinalResult']>
        ) {
          await super.saveFinalResult(...args);
          throw new Error('Injected failure before commit');
        }
      }
      const fail = new FinalizeWeeklyHighlight({
        repository: new FailingRepository(),
        calendar: new PostgresFamilySettingsRepository(),
        transactionRunner: container.transactionRunner,
        newId: randomUUID,
      });
      await expect(fail.execute(f.familyId)).rejects.toThrow('Injected failure');
      expect(await highlights(f)).toEqual([]);
      expect(await deliveries(f)).toEqual([]);
      await container.finalizeWeeklyHighlight.execute(f.familyId);
      expect(await deliveries(f)).toHaveLength(1);
    });

    it('CA-01 applies scheduled time zones and keeps overdue cycles contiguous without app activity', async () => {
      const f = await seedFamily();
      await container.dbPool.query(
        `insert into app.family_time_zone_changes
      (id,family_id,requested_by_member_id,from_time_zone,to_time_zone,application,status,effective_at,requested_at)
      values ($1,$2,$3,'America/Sao_Paulo','Asia/Tokyo','NEXT_CYCLE','SCHEDULED',$4,$4::timestamptz - interval '1 day')`,
        [randomUUID(), f.familyId, f.admin.memberId, END],
      );
      await new WeeklyHighlightWorker(
        container.dbPool,
        container.finalizeWeeklyHighlight,
        logger,
      ).run();
      const rows = (
        await container.dbPool.query(
          'select * from app.weekly_cycles where family_id = $1 order by starts_at',
          [f.familyId],
        )
      ).rows;
      expect(rows.length).toBeGreaterThan(1);
      expect(rows[1]).toMatchObject({
        starts_at: new Date(END),
        time_zone: 'Asia/Tokyo',
        in_transition: true,
      });
      for (let i = 1; i < rows.length; i++) expect(rows[i].starts_at).toEqual(rows[i - 1].ends_at);
      expect((await highlights(f))[0]?.time_zone).toBe('America/Sao_Paulo');
      expect((await highlights(f))[1]?.is_transition).toBe(true);
    });

    it('CA-01/04 finalizes overdue results before an immediate time-zone change', async () => {
      const f = await seedFamily();
      await credit(f, [f.kid]);
      await container.changeFamilyTimeZoneUseCase.execute({
        actor: f.admin,
        timeZoneId: 'Asia/Tokyo',
        application: 'immediate',
      });
      expect((await highlights(f))[0]).toMatchObject({
        cycle_id: f.cycleId,
        starts_at: new Date(START),
        ends_at: new Date(END),
        time_zone: 'America/Sao_Paulo',
      });
      const result = (await container.ownWeeklyRecognitions.list(f.kid)).items[0];
      expect(result?.points).toBe(3);
    });

    it('CA-03 recovers an expired scheduler lease and records retries without duplicating results', async () => {
      const f = await seedFamily();
      await credit(f, [f.kid]);
      await container.dbPool.query(
        `insert into app.weekly_highlight_jobs (family_id,claim_id,lease_until) values ($1,$2,now() - interval '1 second')`,
        [f.familyId, randomUUID()],
      );
      const fail = {
        execute: vi.fn(async () => {
          throw new Error('private failure detail');
        }),
      };
      await new WeeklyHighlightWorker(container.dbPool, fail, logger).run();
      const job = (
        await container.dbPool.query(
          'select * from app.weekly_highlight_jobs where family_id = $1',
          [f.familyId],
        )
      ).rows[0];
      expect(job).toMatchObject({
        state: 'pending',
        attempts: 1,
        last_error: 'FINALIZATION_FAILED',
        claim_id: null,
      });
      await container.dbPool.query(
        'update app.weekly_highlight_jobs set available_at = now() where family_id = $1',
        [f.familyId],
      );
      await Promise.all([
        new WeeklyHighlightWorker(
          container.dbPool,
          container.finalizeWeeklyHighlight,
          logger,
        ).run(),
        new WeeklyHighlightWorker(
          container.dbPool,
          container.finalizeWeeklyHighlight,
          logger,
        ).run(),
      ]);
      expect(await deliveries(f)).toHaveLength(1);
      expect(
        (
          await container.dbPool.query(
            'select * from app.weekly_highlight_jobs where family_id = $1',
            [f.familyId],
          )
        ).rows,
      ).toEqual([]);
    });

    it('CA-05 isolates owners/families and records only the first opening, independently of push', async () => {
      const { family: f, recognition: r } = await recognize();
      const other = await seedFamily();
      for (const actor of [f.admin, f.member, other.kid]) {
        await expect(container.ownWeeklyRecognitions.get(actor, r.id)).rejects.toMatchObject({
          code: 'RESOURCE_NOT_FOUND',
        });
        await expect(container.ownWeeklyRecognitions.open(actor, r.id)).rejects.toMatchObject({
          code: 'RESOURCE_NOT_FOUND',
        });
      }
      const [first, second] = await Promise.all([
        container.ownWeeklyRecognitions.open(f.kid, r.id),
        container.ownWeeklyRecognitions.open(f.kid, r.id),
      ]);
      expect(first.openedAt).not.toBeNull();
      expect(second.openedAt).toBe(first.openedAt);
      expect((await deliveries(f))[0]).toMatchObject({ state: 'pending', accepted_at: null });
      await container.dbPool.query('update app.sessions set revoked_at = now() where id = $1', [
        f.kid.sessionId,
      ]);
      await expect(container.ownWeeklyRecognitions.list(f.kid)).rejects.toMatchObject({
        code: 'SESSION_EXPIRED',
      });
    });

    it('CA-05 revalidates a removed profile after waiting for the family lock', async () => {
      const { family: f } = await recognize();
      const lock = await container.dbPool.getClient();
      await lock.query('begin');
      await lock.query('select pg_advisory_xact_lock(hashtext($1))', [f.familyId]);
      const reading = container.ownWeeklyRecognitions.list(f.kid);
      const denied = expect(reading).rejects.toMatchObject({ code: 'SESSION_EXPIRED' });
      await lock.query('update app.members set removed_at = now() where id = $1', [f.kid.memberId]);
      await lock.query('commit');
      lock.release();
      await denied;
    });

    it('CA-03/06 claims one notification across workers and performs network I/O without holding its row lock', async () => {
      const { family: f, recognition: r } = await recognize();
      await device(f.kid);
      const sendRecognition = vi.fn(async () => {
        const connection = await container.dbPool.getClient();
        try {
          await connection.query('begin');
          await connection.query(
            'select recognition_id from app.recognition_notification_deliveries where recognition_id = $1 for update nowait',
            [r.id],
          );
          await connection.query('commit');
        } finally {
          connection.release();
        }
        return 200;
      });
      await Promise.all([
        new RecognitionPushWorker(container.dbPool, { sendRecognition }, 'development').run(),
        new RecognitionPushWorker(container.dbPool, { sendRecognition }, 'development').run(),
      ]);
      expect(sendRecognition).toHaveBeenCalledTimes(1);
      expect(sendRecognition).toHaveBeenCalledWith('a'.repeat(64), 'development', r.id);
      expect((await deliveries(f))[0]).toMatchObject({ state: 'acceptedByProvider', attempts: 1 });
      expect((await container.ownWeeklyRecognitions.get(f.kid, r.id)).openedAt).toBeNull();
    });

    it('CA-06 keeps results and intentions without a device, rejects wrong environments and revoked sessions', async () => {
      const { family: f, recognition: r } = await recognize();
      const sendRecognition = vi.fn(async () => 200);
      const worker = new RecognitionPushWorker(
        container.dbPool,
        { sendRecognition },
        'development',
      );
      await worker.run();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'pending',
        attempts: 0,
        last_error: 'NO_ACTIVE_DEVICE',
      });
      const id = await device(f.kid, 'production');
      await makeDue(r.id);
      await worker.run();
      expect(sendRecognition).not.toHaveBeenCalled();
      await container.dbPool.query(
        "update app.push_devices set environment='development' where id=$1",
        [id],
      );
      await container.dbPool.query('update app.sessions set revoked_at=now() where id=$1', [
        f.kid.sessionId,
      ]);
      await makeDue(r.id);
      await worker.run();
      expect(sendRecognition).not.toHaveBeenCalled();
      expect(await deliveries(f)).toHaveLength(1);
    });

    it('CA-03/06 retries transient failures and recovers expired claims', async () => {
      const { family: f, recognition: r } = await recognize();
      await device(f.kid);
      await container.dbPool.query(
        `update app.recognition_notification_deliveries set claim_id=$2,lease_until=now()-interval '1 second' where recognition_id=$1`,
        [r.id, randomUUID()],
      );
      const sendRecognition = vi
        .fn()
        .mockRejectedValueOnce(new Error('private token detail'))
        .mockResolvedValue(200);
      const worker = new RecognitionPushWorker(
        container.dbPool,
        { sendRecognition },
        'development',
      );
      await worker.run();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'pending',
        attempts: 1,
        last_error: 'HTTP_503',
      });
      await makeDue(r.id);
      await worker.run();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'acceptedByProvider',
        attempts: 2,
        last_error: null,
      });
      expect((await container.ownWeeklyRecognitions.get(f.kid, r.id)).points).toBe(3);
    });

    it('CA-06 invalidates only the rejected token on APNs 410 and keeps the result consultable', async () => {
      const { family: f, recognition: r } = await recognize();
      const id = await device(f.kid);
      await new RecognitionPushWorker(
        container.dbPool,
        { sendRecognition: async () => 410 },
        'development',
      ).run();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'failed',
        attempts: 1,
        last_error: 'HTTP_410',
      });
      expect(
        (await container.dbPool.query('select revoked_at from app.push_devices where id=$1', [id]))
          .rows[0]?.revoked_at,
      ).not.toBeNull();
      expect((await container.ownWeeklyRecognitions.get(f.kid, r.id)).points).toBe(3);
    });

    it('CA-03 ignores an obsolete delivery response after another worker obtains the claim', async () => {
      const { family: f, recognition: r } = await recognize();
      await device(f.kid);
      const newClaim = randomUUID();
      const sendRecognition = async () => {
        await container.dbPool.query(
          `update app.recognition_notification_deliveries set claim_id=$2,lease_until=now()+interval '1 minute' where recognition_id=$1`,
          [r.id, newClaim],
        );
        return 200;
      };
      await new RecognitionPushWorker(container.dbPool, { sendRecognition }, 'development').run();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'pending',
        claim_id: newClaim,
        accepted_at: null,
      });
    });

    it('CA-03/06 stops after the configured limit even if the last sender crashed', async () => {
      const { family: f, recognition: r } = await recognize();
      await device(f.kid);
      await container.dbPool.query(
        `update app.recognition_notification_deliveries
        set attempts = 2, claim_id = $2, lease_until = now() - interval '1 second'
        where recognition_id = $1`,
        [r.id, randomUUID()],
      );
      const sendRecognition = vi.fn(async () => 200);
      await new RecognitionPushWorker(
        container.dbPool,
        { sendRecognition },
        'development',
        2,
      ).run();
      expect(sendRecognition).not.toHaveBeenCalled();
      expect((await deliveries(f))[0]).toMatchObject({
        state: 'failed',
        attempts: 2,
        last_error: 'RETRY_LIMIT_REACHED',
      });
      expect((await container.ownWeeklyRecognitions.get(f.kid, r.id)).points).toBe(3);
    });

    it('CA-01 respects a persisted cycle across daylight-saving boundaries', async () => {
      const f = await seedFamily();
      await container.dbPool.query(
        `update app.weekly_cycles set starts_at='2026-10-26T04:00:00Z',
        ends_at='2026-11-02T05:00:00Z', time_zone='America/New_York', reference_week='2026-10-26'
        where id=$1`,
        [f.cycleId],
      );
      await container.dbPool.query(
        "update app.families set timezone='America/New_York' where id=$1",
        [f.familyId],
      );
      await credit(f, [f.kid], 3, '2026-11-02T04:59:59.999Z');
      await credit(f, [f.member], 3, '2026-11-02T05:00:00.000Z');
      await container.finalizeWeeklyHighlight.execute(f.familyId);
      const result = (await container.ownWeeklyRecognitions.list(f.kid)).items[0]!;
      expect(result.period).toMatchObject({
        startsAt: '2026-10-26T04:00:00.000Z',
        endsAt: '2026-11-02T05:00:00.000Z',
      });
      expect(result.points).toBe(3);
      expect(
        (await container.ownWeeklyRecognitions.list(f.member)).items.some(
          (item) => item.period.startsAt === result.period.startsAt,
        ),
      ).toBe(false);
    });

    it('CA-05 keeps new tables private and rejects cross-family references', async () => {
      const { family: f } = await recognize();
      const other = await seedFamily();
      const highlight = (await highlights(f))[0]!;
      await expect(
        container.dbPool.query(
          `insert into app.weekly_recognitions (id,family_id,highlight_id,member_id,points,completed_tasks)
      values ($1,$2,$3,$4,1,1)`,
          [randomUUID(), f.familyId, highlight.id, other.kid.memberId],
        ),
      ).rejects.toMatchObject({ code: '23503' });
      for (const table of [
        'weekly_highlights',
        'weekly_recognitions',
        'recognition_notification_deliveries',
        'weekly_highlight_jobs',
      ]) {
        const permission = await container.dbPool.query(
          `select has_table_privilege('anon',$1,'SELECT') as anon, has_table_privilege('authenticated',$1,'SELECT') as authenticated`,
          [`app.${table}`],
        );
        expect(permission.rows[0]).toEqual({ anon: false, authenticated: false });
      }
    });
  },
);
