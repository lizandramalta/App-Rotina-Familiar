/**
 * Regras puras da mudança de fuso (SPEC-002 Fase 3): CA-06, CA-07 e CA-08, mais a
 * liquidação de ciclos vencidos (decisões E-07/E-08).
 */
import { describe, expect, it } from 'vitest';
import {
  planTimeZoneChange,
  settleCycles,
  type CycleLimits,
} from '../../src/modules/family/domain/time-zone-change-planner.js';
import {
  buildInitialWeeklyCycle,
  nextWeekStart,
  referenceWeekOf,
} from '../../src/modules/family/domain/weekly-cycle.js';

const SP = 'America/Sao_Paulo';
const TOKYO = 'Asia/Tokyo';

// Quarta-feira 2026-10-07 12:00 em São Paulo (UTC-3).
const WEDNESDAY = new Date('2026-10-07T15:00:00.000Z');

function openCycleFor(now: Date, timeZoneId = SP): CycleLimits {
  const cycle = buildInitialWeeklyCycle(now, timeZoneId);
  return {
    startsAt: cycle.startsAt,
    endsAt: cycle.endsAt,
    timeZoneId,
    isTransition: false,
  };
}

describe('nextWeekStart', () => {
  it('returns the next Monday 00:00 local, strictly after the instant', () => {
    // Segunda 2026-10-12 00:00 em São Paulo = 03:00Z.
    expect(nextWeekStart(WEDNESDAY, SP).toISOString()).toBe('2026-10-12T03:00:00.000Z');
  });

  it('moves to the following Monday when the instant already is Monday 00:00 local', () => {
    const monday = new Date('2026-10-12T03:00:00.000Z');
    expect(nextWeekStart(monday, SP).toISOString()).toBe('2026-10-19T03:00:00.000Z');
  });

  it('reads the week in the given zone, not in UTC', () => {
    // Domingo 23:00 em São Paulo ainda é a semana que termina na segunda local.
    const sundayNight = new Date('2026-10-12T02:00:00.000Z');
    expect(nextWeekStart(sundayNight, SP).toISOString()).toBe('2026-10-12T03:00:00.000Z');
    // Já em Tóquio o mesmo instante é segunda 11:00.
    expect(nextWeekStart(sundayNight, TOKYO).toISOString()).toBe('2026-10-18T15:00:00.000Z');
  });
});

describe('referenceWeekOf', () => {
  it('is the civil Monday of the week in the zone', () => {
    expect(referenceWeekOf(WEDNESDAY, SP)).toBe('2026-10-05');
  });
});

describe('planTimeZoneChange (CA-06, CA-07, CA-08)', () => {
  const open = openCycleFor(WEDNESDAY);

  it('immediate: keeps the cycle start and ends on the next Monday 00:00 in the new zone', () => {
    const plan = planTimeZoneChange({
      open,
      timeZoneId: TOKYO,
      application: 'immediate',
      now: WEDNESDAY,
    });

    expect(plan.effectiveAt).toEqual(WEDNESDAY);
    expect(plan.effectiveLimits.startsAt).toEqual(open.startsAt);
    // Segunda 2026-10-12 00:00 em Tóquio (UTC+9) = domingo 15:00Z.
    expect(plan.effectiveLimits.endsAt.toISOString()).toBe('2026-10-11T15:00:00.000Z');
    expect(plan.effectiveLimits.endsAt.getTime()).toBeGreaterThan(WEDNESDAY.getTime());
    expect(plan.effectiveLimits.timeZoneId).toBe(TOKYO);
    expect(plan.effectiveLimits.isTransition).toBe(true);
  });

  it('immediate: the end is strictly after the change even on a Monday 00:00 local', () => {
    const mondayStart = new Date('2026-10-12T03:00:00.000Z');
    const plan = planTimeZoneChange({
      open: openCycleFor(mondayStart),
      timeZoneId: 'America/Manaus',
      application: 'immediate',
      now: mondayStart,
    });

    expect(plan.effectiveLimits.endsAt.getTime()).toBeGreaterThan(mondayStart.getTime());
  });

  it('nextCycle: leaves the current cycle alone and starts the new zone at its end', () => {
    const plan = planTimeZoneChange({
      open,
      timeZoneId: TOKYO,
      application: 'nextCycle',
      now: WEDNESDAY,
    });

    expect(plan.effectiveAt).toEqual(open.endsAt);
    expect(plan.effectiveLimits.startsAt).toEqual(open.endsAt);
    // Primeira segunda 00:00 em Tóquio estritamente depois de 2026-10-12T03:00Z.
    expect(plan.effectiveLimits.endsAt.toISOString()).toBe('2026-10-18T15:00:00.000Z');
    expect(plan.effectiveLimits.isTransition).toBe(true);
  });

  it('never moves the end before the start', () => {
    for (const zone of [TOKYO, 'America/Los_Angeles', 'Pacific/Kiritimati', 'Pacific/Pago_Pago']) {
      for (const application of ['immediate', 'nextCycle'] as const) {
        const { effectiveLimits } = planTimeZoneChange({
          open,
          timeZoneId: zone,
          application,
          now: WEDNESDAY,
        });
        expect(effectiveLimits.endsAt.getTime()).toBeGreaterThan(
          effectiveLimits.startsAt.getTime(),
        );
      }
    }
  });
});

describe('settleCycles (decisões E-07/E-08)', () => {
  const open = openCycleFor(WEDNESDAY);

  it('changes nothing while the open cycle has not ended', () => {
    const settled = settleCycles({
      open,
      familyTimeZoneId: SP,
      scheduled: undefined,
      now: WEDNESDAY,
    });

    expect(settled.created).toEqual([]);
    expect(settled.open).toEqual(open);
    expect(settled.appliedScheduledId).toBeUndefined();
  });

  it('creates contiguous weekly cycles until the one that contains now', () => {
    const now = new Date('2026-10-28T15:00:00.000Z'); // 2.5 semanas depois
    const settled = settleCycles({ open, familyTimeZoneId: SP, scheduled: undefined, now });

    expect(settled.created).toHaveLength(3);
    expect(settled.created[0]?.startsAt).toEqual(open.endsAt);
    for (let index = 1; index < settled.created.length; index += 1) {
      expect(settled.created[index]?.startsAt).toEqual(settled.created[index - 1]?.endsAt);
    }
    const last = settled.created[2];
    expect(last?.startsAt.getTime()).toBeLessThanOrEqual(now.getTime());
    expect(last?.endsAt.getTime()).toBeGreaterThan(now.getTime());
    expect(settled.created.every((cycle) => !cycle.isTransition)).toBe(true);
  });

  it('applies the scheduled zone in the first cycle that starts at its effective date', () => {
    const plan = planTimeZoneChange({
      open,
      timeZoneId: TOKYO,
      application: 'nextCycle',
      now: WEDNESDAY,
    });
    const now = new Date('2026-10-13T15:00:00.000Z');

    const settled = settleCycles({
      open,
      familyTimeZoneId: SP,
      scheduled: { id: 'change-1', timeZoneId: TOKYO, effectiveAt: plan.effectiveAt },
      now,
    });

    expect(settled.appliedScheduledId).toBe('change-1');
    expect(settled.familyTimeZoneId).toBe(TOKYO);
    expect(settled.created[0]).toMatchObject({
      timeZoneId: TOKYO,
      isTransition: true,
      startsAt: open.endsAt,
    });
    expect(settled.created[0]?.endsAt).toEqual(plan.effectiveLimits.endsAt);
  });

  it('keeps the scheduled zone pending until the cycle really ends', () => {
    const settled = settleCycles({
      open,
      familyTimeZoneId: SP,
      scheduled: { id: 'change-1', timeZoneId: TOKYO, effectiveAt: open.endsAt },
      now: WEDNESDAY,
    });

    expect(settled.appliedScheduledId).toBeUndefined();
    expect(settled.familyTimeZoneId).toBe(SP);
  });
});
