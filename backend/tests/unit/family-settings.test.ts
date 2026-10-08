/**
 * Casos de uso de fuso — SPEC-002 Fase 3: CA-05 a CA-08 e CA-09.
 *
 * O repositório é um dublê em memória com rollback real: o que está sob teste é a
 * orquestração (RBAC após o lock, prévia sem gravação, supressão da programada,
 * ciclos preservados). Locks e constraints são provados em tests/integration.
 */
import { beforeEach, describe, expect, it } from 'vitest';
import { ChangeFamilyTimeZoneUseCase } from '../../src/modules/family/application/change-family-time-zone-use-case.js';
import { GetFamilySettingsUseCase } from '../../src/modules/family/application/get-family-settings-use-case.js';
import { PreviewFamilyTimeZoneChangeUseCase } from '../../src/modules/family/application/preview-family-time-zone-change-use-case.js';
import type { FamilySettingsRepositoryPort } from '../../src/modules/family/application/family-settings-repository-port.js';
import type {
  CycleLimits,
  NewCycle,
  ScheduledChange,
} from '../../src/modules/family/domain/time-zone-change-planner.js';
import { buildInitialWeeklyCycle } from '../../src/modules/family/domain/weekly-cycle.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  NotFoundError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { createRecordingLogger } from '../support/fake-logger.js';

type MemberRoleValue = (typeof MemberRole)[keyof typeof MemberRole];

const SP = 'America/Sao_Paulo';
const TOKYO = 'Asia/Tokyo';
const CREATED_AT = new Date('2026-10-07T15:00:00.000Z'); // quarta 12:00 em SP
const FAMILY_ID = 'family-1';
const ADMIN_ID = 'admin-1';

interface ChangeRow {
  id: string;
  familyId: string;
  from: string;
  to: string;
  application: string;
  status: string;
  effectiveAt: Date;
}

interface State {
  roles: Map<string, string>; // `${familyId}:${memberId}` -> role
  timeZones: Map<string, string>;
  cycles: Array<CycleLimits & { familyId: string }>;
  changes: ChangeRow[];
}

class InMemorySettings implements FamilySettingsRepositoryPort {
  public failOnInsertChange = false;

  constructor(public state: State) {}

  public async findMemberRole(
    _tx: TransactionContext,
    p: { familyId: string; memberId: string },
  ): Promise<MemberRoleValue | undefined> {
    return this.state.roles.get(`${p.familyId}:${p.memberId}`) as MemberRoleValue | undefined;
  }
  public async findFamilyTimeZone(_tx: TransactionContext, familyId: string) {
    return this.state.timeZones.get(familyId);
  }
  public async findOpenCycle(_tx: TransactionContext, familyId: string) {
    const cycles = this.state.cycles
      .filter((cycle) => cycle.familyId === familyId)
      .sort((a, b) => b.startsAt.getTime() - a.startsAt.getTime());
    return cycles[0];
  }
  public async findScheduledChange(
    _tx: TransactionContext,
    familyId: string,
  ): Promise<ScheduledChange | undefined> {
    const row = this.state.changes.find(
      (change) => change.familyId === familyId && change.status === 'SCHEDULED',
    );
    return row === undefined
      ? undefined
      : { id: row.id, timeZoneId: row.to, effectiveAt: row.effectiveAt };
  }
  public async insertCycle(
    _tx: TransactionContext,
    p: { cycleId: string; familyId: string; cycle: NewCycle },
  ) {
    this.state.cycles.push({ ...p.cycle, familyId: p.familyId });
  }
  public async updateCycleLimits(
    _tx: TransactionContext,
    p: {
      familyId: string;
      startsAt: Date;
      endsAt: Date;
      timeZoneId: string;
      isTransition: boolean;
    },
  ) {
    const index = this.state.cycles.findIndex(
      (cycle) => cycle.familyId === p.familyId && cycle.startsAt.getTime() === p.startsAt.getTime(),
    );
    const current = this.state.cycles[index];
    if (current === undefined) throw new Error('no such cycle');
    this.state.cycles[index] = {
      ...current,
      endsAt: p.endsAt,
      timeZoneId: p.timeZoneId,
      isTransition: p.isTransition,
    };
  }
  public async updateFamilyTimeZone(
    _tx: TransactionContext,
    p: { familyId: string; timeZoneId: string },
  ) {
    this.state.timeZones.set(p.familyId, p.timeZoneId);
  }
  public async insertChange(
    _tx: TransactionContext,
    p: {
      changeId: string;
      familyId: string;
      fromTimeZoneId: string;
      toTimeZoneId: string;
      application: string;
      status: string;
      effectiveAt: Date;
    },
  ) {
    if (this.failOnInsertChange) throw new Error('connection reset');
    this.state.changes.push({
      id: p.changeId,
      familyId: p.familyId,
      from: p.fromTimeZoneId,
      to: p.toTimeZoneId,
      application: p.application,
      status: p.status,
      effectiveAt: p.effectiveAt,
    });
  }
  public async resolveChange(
    _tx: TransactionContext,
    p: { changeId: string; status: 'APPLIED' | 'SUPERSEDED' },
  ) {
    const row = this.state.changes.find((change) => change.id === p.changeId);
    if (row !== undefined) row.status = p.status;
  }
}

function cloneState(state: State): State {
  return {
    roles: new Map(state.roles),
    timeZones: new Map(state.timeZones),
    cycles: state.cycles.map((cycle) => ({ ...cycle })),
    changes: state.changes.map((change) => ({ ...change })),
  };
}

describe('family time zone use cases', () => {
  let repository: InMemorySettings;
  let now: Date;
  let idCounter: number;
  let lockedFamilies: string[];
  let beforeLock: (() => void) | undefined;
  let logs: ReturnType<typeof createRecordingLogger>;

  const clock: Clock = { now: () => now, nowIsoString: () => now.toISOString() };
  const crypto = { newId: () => `id-${(idCounter += 1)}` };

  const runner: TransactionRunner = {
    async run(work) {
      const snapshot = cloneState(repository.state);
      try {
        return await work({ client: {} });
      } catch (error) {
        repository.state = snapshot; // rollback
        throw error;
      }
    },
    async forFamily(familyId, work) {
      lockedFamilies.push(familyId);
      // Simula a espera do lock: o estado pode mudar antes de a transação ler.
      beforeLock?.();
      return runner.run(work);
    },
  };

  const actorOf = (role: ActorContext['role'], memberId = ADMIN_ID): ActorContext => ({
    sessionId: 'session-1',
    familyId: FAMILY_ID,
    memberId,
    role,
    isFamilyCreator: role === MemberRole.ADMINISTRATOR,
  });

  const admin = actorOf(MemberRole.ADMINISTRATOR);

  const build = () => {
    const deps = { repository, transactionRunner: runner, clock, logger: logs.logger };
    return {
      get: new GetFamilySettingsUseCase({ ...deps, crypto }),
      preview: new PreviewFamilyTimeZoneChangeUseCase(deps),
      change: new ChangeFamilyTimeZoneUseCase({ ...deps, crypto }),
    };
  };

  beforeEach(() => {
    now = new Date('2026-10-08T15:00:00.000Z'); // quinta 12:00 em SP
    idCounter = 0;
    lockedFamilies = [];
    beforeLock = undefined;
    logs = createRecordingLogger();

    const initial = buildInitialWeeklyCycle(CREATED_AT, SP);
    repository = new InMemorySettings({
      roles: new Map([
        [`${FAMILY_ID}:${ADMIN_ID}`, MemberRole.ADMINISTRATOR],
        [`${FAMILY_ID}:member-1`, MemberRole.MEMBER],
        [`${FAMILY_ID}:kid-1`, MemberRole.KIDS],
        ['family-2:admin-2', MemberRole.ADMINISTRATOR],
      ]),
      timeZones: new Map([
        [FAMILY_ID, SP],
        ['family-2', SP],
      ]),
      cycles: [
        {
          familyId: FAMILY_ID,
          startsAt: initial.startsAt,
          endsAt: initial.endsAt,
          timeZoneId: SP,
          isTransition: false,
        },
        {
          familyId: 'family-2',
          startsAt: initial.startsAt,
          endsAt: initial.endsAt,
          timeZoneId: SP,
          isTransition: false,
        },
      ],
      changes: [],
    });
  });

  describe('CA-05: only Administrators', () => {
    it.each([MemberRole.MEMBER, MemberRole.KIDS])(
      'answers ACTION_NOT_ALLOWED to %s on all three operations without touching the database',
      async (role) => {
        const useCases = build();
        const actor = actorOf(role, role === MemberRole.KIDS ? 'kid-1' : 'member-1');
        const body = { timeZoneId: TOKYO, application: 'immediate' };

        for (const run of [
          () => useCases.get.execute({ actor }),
          () => useCases.preview.execute({ actor, ...body }),
          () => useCases.change.execute({ actor, ...body }),
        ]) {
          await expect(run()).rejects.toBeInstanceOf(ActionNotAllowedError);
        }

        expect(lockedFamilies).toEqual([]);
        expect(repository.state.changes).toEqual([]);
      },
    );

    it('revalidates the role after the lock: a session demoted while waiting is refused', async () => {
      // A sessão ainda diz "administrator"; o banco já rebaixou o membro.
      beforeLock = () => repository.state.roles.set(`${FAMILY_ID}:${ADMIN_ID}`, MemberRole.MEMBER);

      await expect(
        build().change.execute({ actor: admin, timeZoneId: TOKYO, application: 'immediate' }),
      ).rejects.toBeInstanceOf(ActionNotAllowedError);

      expect(repository.state.timeZones.get(FAMILY_ID)).toBe(SP);
      expect(repository.state.changes).toEqual([]);
    });

    it('treats a session whose member is not in the family as not found', async () => {
      await expect(
        build().get.execute({ actor: actorOf(MemberRole.ADMINISTRATOR, 'ghost') }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  describe('GET settings', () => {
    it('returns the zone, no scheduled change and the open cycle limits', async () => {
      const result = await build().get.execute({ actor: admin });

      expect(result).toEqual({
        timeZoneId: SP,
        scheduledTimeZoneChange: null,
        limits: {
          startsAt: CREATED_AT.toISOString(),
          endsAt: '2026-10-12T03:00:00.000Z',
          timeZoneId: SP,
          isTransition: false,
        },
      });
    });

    it('settles expired cycles and applies a due scheduled change (E-07/E-08)', async () => {
      const useCases = build();
      await useCases.change.execute({ actor: admin, timeZoneId: TOKYO, application: 'nextCycle' });

      now = new Date('2026-10-14T15:00:00.000Z'); // depois do encerramento
      const result = await useCases.get.execute({ actor: admin });

      expect(result.timeZoneId).toBe(TOKYO);
      expect(result.scheduledTimeZoneChange).toBeNull();
      expect(result.limits).toMatchObject({ timeZoneId: TOKYO, isTransition: true });
      expect(repository.state.timeZones.get(FAMILY_ID)).toBe(TOKYO);
      expect(repository.state.changes[0]?.status).toBe('APPLIED');
      expect(repository.state.cycles.filter((c) => c.familyId === FAMILY_ID)).toHaveLength(2);
    });
  });

  describe('CA-06/CA-07: preview never writes', () => {
    it('returns the effective limits and leaves the state untouched', async () => {
      const before = cloneState(repository.state);

      const preview = await build().preview.execute({
        actor: admin,
        timeZoneId: TOKYO,
        application: 'immediate',
      });

      expect(preview).toMatchObject({
        proposedTimeZoneId: TOKYO,
        application: 'immediate',
        effectiveAt: now.toISOString(),
        isTransition: true,
        effectiveLimits: { startsAt: CREATED_AT.toISOString(), timeZoneId: TOKYO },
      });
      expect(repository.state).toEqual(before);
      expect(lockedFamilies).toEqual([]);
    });

    it('does not even persist the settlement of expired cycles', async () => {
      now = new Date('2026-10-30T15:00:00.000Z');
      const before = cloneState(repository.state);

      const preview = await build().preview.execute({
        actor: admin,
        timeZoneId: TOKYO,
        application: 'nextCycle',
      });

      expect(preview.effectiveLimits.startsAt > '2026-10-30').toBe(true);
      expect(repository.state).toEqual(before);
    });
  });

  describe('CA-06: immediate application', () => {
    it('changes the zone, keeps the cycle start and ends on the next Monday in the new zone', async () => {
      const result = await build().change.execute({
        actor: admin,
        timeZoneId: TOKYO,
        application: 'immediate',
      });

      expect(result.timeZoneId).toBe(TOKYO);
      expect(result.scheduledTimeZoneChange).toBeNull();
      expect(result.limits).toEqual({
        startsAt: CREATED_AT.toISOString(),
        endsAt: '2026-10-11T15:00:00.000Z',
        timeZoneId: TOKYO,
        isTransition: true,
      });
      expect(repository.state.timeZones.get(FAMILY_ID)).toBe(TOKYO);
      expect(repository.state.changes).toMatchObject([
        { from: SP, to: TOKYO, application: 'immediate', status: 'APPLIED' },
      ]);
    });

    it('supersedes a pending scheduled change (last valid request wins)', async () => {
      const useCases = build();
      await useCases.change.execute({ actor: admin, timeZoneId: TOKYO, application: 'nextCycle' });
      await useCases.change.execute({
        actor: admin,
        timeZoneId: 'America/Manaus',
        application: 'immediate',
      });

      expect(repository.state.changes.map((change) => change.status)).toEqual([
        'SUPERSEDED',
        'APPLIED',
      ]);
      const result = await useCases.get.execute({ actor: admin });
      expect(result.scheduledTimeZoneChange).toBeNull();
      expect(result.timeZoneId).toBe('America/Manaus');
    });
  });

  describe('CA-07: next cycle application', () => {
    it('keeps the current zone and cycle, and exposes the scheduled change', async () => {
      const result = await build().change.execute({
        actor: admin,
        timeZoneId: TOKYO,
        application: 'nextCycle',
      });

      expect(result.timeZoneId).toBe(SP);
      expect(result.limits).toMatchObject({
        endsAt: '2026-10-12T03:00:00.000Z',
        timeZoneId: SP,
        isTransition: false,
      });
      expect(result.scheduledTimeZoneChange).toEqual({
        timeZoneId: TOKYO,
        effectiveAt: '2026-10-12T03:00:00.000Z',
      });
      expect(repository.state.timeZones.get(FAMILY_ID)).toBe(SP);
    });

    it('replaces a previous scheduled change with the latest request', async () => {
      const useCases = build();
      await useCases.change.execute({ actor: admin, timeZoneId: TOKYO, application: 'nextCycle' });
      const result = await useCases.change.execute({
        actor: admin,
        timeZoneId: 'America/Manaus',
        application: 'nextCycle',
      });

      expect(result.scheduledTimeZoneChange?.timeZoneId).toBe('America/Manaus');
      expect(repository.state.changes.map((change) => change.status)).toEqual([
        'SUPERSEDED',
        'SCHEDULED',
      ]);
    });
  });

  describe('CA-08: history is preserved', () => {
    it('never modifies a cycle that already ended', async () => {
      now = new Date('2026-10-20T15:00:00.000Z'); // dois ciclos depois
      const ended = { ...repository.state.cycles[0]! };

      await build().change.execute({ actor: admin, timeZoneId: TOKYO, application: 'immediate' });

      const cycles = repository.state.cycles
        .filter((cycle) => cycle.familyId === FAMILY_ID)
        .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
      expect(cycles[0]).toMatchObject({
        startsAt: ended.startsAt,
        endsAt: ended.endsAt,
        timeZoneId: SP,
        isTransition: false,
      });
      expect(cycles.at(-1)).toMatchObject({ timeZoneId: TOKYO, isTransition: true });
    });

    it('never touches another family', async () => {
      const other = cloneState(repository.state).cycles.filter((c) => c.familyId === 'family-2');

      await build().change.execute({ actor: admin, timeZoneId: TOKYO, application: 'immediate' });

      expect(repository.state.timeZones.get('family-2')).toBe(SP);
      expect(repository.state.cycles.filter((c) => c.familyId === 'family-2')).toEqual(other);
    });
  });

  describe('validation (CA-02 style codes)', () => {
    it.each([
      [
        { timeZoneId: 'Not/AZone', application: 'immediate' },
        { timeZoneId: ['TIME_ZONE_ID_INVALID'] },
      ],
      [
        { timeZoneId: undefined, application: 'immediate' },
        { timeZoneId: ['TIME_ZONE_ID_INVALID'] },
      ],
      [{ timeZoneId: 42, application: 'immediate' }, { timeZoneId: ['TIME_ZONE_ID_INVALID'] }],
      [
        { timeZoneId: TOKYO, application: 'later' },
        { application: ['TIME_ZONE_APPLICATION_INVALID'] },
      ],
      [
        { timeZoneId: TOKYO, application: undefined },
        { application: ['TIME_ZONE_APPLICATION_INVALID'] },
      ],
      [
        { timeZoneId: '+03:00', application: null },
        {
          timeZoneId: ['TIME_ZONE_ID_INVALID'],
          application: ['TIME_ZONE_APPLICATION_INVALID'],
        },
      ],
    ])('refuses %j with 422 field errors on preview and change', async (body, fieldErrors) => {
      const useCases = build();

      for (const run of [
        () => useCases.preview.execute({ actor: admin, ...body }),
        () => useCases.change.execute({ actor: admin, ...body }),
      ]) {
        const error = await run().catch((caught: unknown) => caught);
        expect(error).toBeInstanceOf(ValidationError);
        expect((error as ValidationError).statusCode).toBe(422);
        expect((error as ValidationError).fieldErrors).toEqual(fieldErrors);
      }
      expect(repository.state.changes).toEqual([]);
    });

    it('refuses the zone already in effect with TIME_ZONE_UNCHANGED (E-09)', async () => {
      const useCases = build();

      for (const application of ['immediate', 'nextCycle']) {
        for (const run of [
          () => useCases.preview.execute({ actor: admin, timeZoneId: SP, application }),
          () => useCases.change.execute({ actor: admin, timeZoneId: SP, application }),
        ]) {
          const error = await run().catch((caught: unknown) => caught);
          expect(error).toBeInstanceOf(ValidationError);
          expect((error as ValidationError).fieldErrors).toEqual({
            timeZoneId: ['TIME_ZONE_UNCHANGED'],
          });
        }
      }
      expect(repository.state.changes).toEqual([]);
    });

    it('compares against the zone that is in effect after settling, not the stale one', async () => {
      const useCases = build();
      await useCases.change.execute({ actor: admin, timeZoneId: TOKYO, application: 'nextCycle' });
      now = new Date('2026-10-14T15:00:00.000Z');

      const error = await useCases.change
        .execute({ actor: admin, timeZoneId: TOKYO, application: 'immediate' })
        .catch((caught: unknown) => caught);

      expect((error as ValidationError).fieldErrors).toEqual({
        timeZoneId: ['TIME_ZONE_UNCHANGED'],
      });
    });
  });

  describe('CA-09: persistence failure', () => {
    it('answers 503 without claiming a rollback, rolls back everything and logs no zone data', async () => {
      repository.failOnInsertChange = true;
      const before = cloneState(repository.state);

      const error = await build()
        .change.execute({ actor: admin, timeZoneId: TOKYO, application: 'immediate' })
        .catch((caught: unknown) => caught);

      expect(error).toBeInstanceOf(DependencyUnavailableError);
      expect((error as DependencyUnavailableError).message).not.toMatch(/roll/i);
      expect(repository.state).toEqual(before);
      expect(JSON.stringify(logs.calls)).not.toContain(TOKYO);
    });
  });
});
