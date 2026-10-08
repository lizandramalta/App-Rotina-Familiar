/**
 * Regras de domínio da criação de família (SPEC-002): nome, apelido, fuso IANA
 * e ciclo semanal inicial. Cobre CA-02 e o "ciclo inicial" de CA-01.
 */
import { describe, it, expect } from 'vitest';
import { normalizeName, normalizeNickname } from '../../src/modules/family/domain/text-rules.js';
import {
  DEFAULT_TIME_ZONE_ID,
  isValidTimeZoneId,
  startOfLocalDay,
} from '../../src/modules/family/domain/time-zone.js';
import { buildInitialWeeklyCycle } from '../../src/modules/family/domain/weekly-cycle.js';

describe('normalizeName (CA-02, RF01/RF02)', () => {
  it('trims the value and accepts 1 to 60 visible characters', () => {
    expect(normalizeName('  Casa Silva  ')).toEqual({ value: 'Casa Silva' });
    expect(normalizeName('a')).toEqual({ value: 'a' });
    expect(normalizeName('a'.repeat(60))).toEqual({ value: 'a'.repeat(60) });
  });

  it('rejects empty, whitespace-only and non-string input as REQUIRED', () => {
    expect(normalizeName('')).toEqual({ problem: 'REQUIRED' });
    expect(normalizeName('   ')).toEqual({ problem: 'REQUIRED' });
    expect(normalizeName(undefined)).toEqual({ problem: 'REQUIRED' });
    expect(normalizeName(42)).toEqual({ problem: 'REQUIRED' });
  });

  it('rejects more than 60 visible characters after trim', () => {
    expect(normalizeName('a'.repeat(61))).toEqual({ problem: 'INVALID_LENGTH' });
  });

  it('counts a composed emoji as one visible character', () => {
    const family = '👨‍👩‍👧‍👦';
    expect(normalizeName(family.repeat(60))).toEqual({ value: family.repeat(60) });
    expect(normalizeName(family.repeat(61))).toEqual({ problem: 'INVALID_LENGTH' });
  });

  it('rejects control characters anywhere, including the edges trim would remove', () => {
    expect(normalizeName('Casa\u0000Silva')).toEqual({ problem: 'INVALID_CONTENT' });
    expect(normalizeName('Casa\nSilva')).toEqual({ problem: 'INVALID_CONTENT' });
    expect(normalizeName('Casa Silva\n')).toEqual({ problem: 'INVALID_CONTENT' });
  });
});

describe('normalizeNickname (RN63, RF48)', () => {
  it('treats undefined, null and blank as no nickname', () => {
    expect(normalizeNickname(undefined)).toEqual({ value: null });
    expect(normalizeNickname(null)).toEqual({ value: null });
    expect(normalizeNickname('   ')).toEqual({ value: null });
  });

  it('accepts up to 20 non-space characters; inner spaces do not count', () => {
    expect(normalizeNickname('a'.repeat(20))).toEqual({ value: 'a'.repeat(20) });
    expect(normalizeNickname('  Mari  ')).toEqual({ value: 'Mari' });
    expect(normalizeNickname('a b '.repeat(10).trim())).toEqual({
      value: 'a b '.repeat(10).trim(),
    });
  });

  it('rejects 21 or more non-space characters', () => {
    expect(normalizeNickname('a'.repeat(21))).toEqual({ problem: 'INVALID_LENGTH' });
    expect(normalizeNickname('a b '.repeat(11).trim())).toEqual({ problem: 'INVALID_LENGTH' });
  });

  it('rejects control characters', () => {
    expect(normalizeNickname('Ma\tri')).toEqual({ problem: 'INVALID_CONTENT' });
  });
});

describe('isValidTimeZoneId (RF67)', () => {
  it.each([DEFAULT_TIME_ZONE_ID, 'America/New_York', 'Europe/Lisbon', 'UTC', 'Asia/Tokyo'])(
    'accepts %s',
    (id) => expect(isValidTimeZoneId(id)).toBe(true),
  );

  it.each(['', 'Mars/Olympus', 'brasilia', '+03:00', 'America/', '../etc/passwd', 'a b'])(
    'rejects %j',
    (id) => expect(isValidTimeZoneId(id)).toBe(false),
  );
});

describe('startOfLocalDay', () => {
  it('returns local midnight as a UTC instant', () => {
    // São Paulo é UTC-3 sem horário de verão desde 2019.
    expect(
      startOfLocalDay({ year: 2026, month: 10, day: 12 }, 'America/Sao_Paulo').toISOString(),
    ).toBe('2026-10-12T03:00:00.000Z');
    expect(startOfLocalDay({ year: 2026, month: 10, day: 12 }, 'UTC').toISOString()).toBe(
      '2026-10-12T00:00:00.000Z',
    );
    expect(startOfLocalDay({ year: 2026, month: 10, day: 12 }, 'Asia/Tokyo').toISOString()).toBe(
      '2026-10-11T15:00:00.000Z',
    );
  });

  it('respects the daylight saving offset of the date', () => {
    // Nova York: UTC-4 em outubro (horário de verão) e UTC-5 em dezembro.
    expect(
      startOfLocalDay({ year: 2026, month: 10, day: 12 }, 'America/New_York').toISOString(),
    ).toBe('2026-10-12T04:00:00.000Z');
    expect(
      startOfLocalDay({ year: 2026, month: 12, day: 14 }, 'America/New_York').toISOString(),
    ).toBe('2026-12-14T05:00:00.000Z');
  });

  it('returns the first existing instant when local midnight does not exist', () => {
    // Santiago avança o relógio à meia-noite de 2026-09-06: 00:00 não existe.
    const start = startOfLocalDay({ year: 2026, month: 9, day: 6 }, 'America/Santiago');
    expect(start.toISOString()).toBe('2026-09-06T04:00:00.000Z');
  });
});

describe('buildInitialWeeklyCycle (SPEC-002 §3.1)', () => {
  it('starts at creation and ends on the next Monday 00:00 in the family time zone', () => {
    // Quinta-feira 2026-10-08 12:00 UTC = 09:00 em São Paulo.
    const now = new Date('2026-10-08T12:00:00.000Z');
    const cycle = buildInitialWeeklyCycle(now, 'America/Sao_Paulo');

    expect(cycle.startsAt).toEqual(now);
    expect(cycle.endsAt.toISOString()).toBe('2026-10-12T03:00:00.000Z');
    expect(cycle.timeZoneId).toBe('America/Sao_Paulo');
    expect(cycle.referenceWeek).toBe('2026-10-05');
  });

  it('ends on the following Monday when created on a Monday', () => {
    const monday = new Date('2026-10-12T15:00:00.000Z');
    const cycle = buildInitialWeeklyCycle(monday, 'America/Sao_Paulo');

    expect(cycle.endsAt.toISOString()).toBe('2026-10-19T03:00:00.000Z');
    expect(cycle.referenceWeek).toBe('2026-10-12');
  });

  it('ends the next day when created on a Sunday', () => {
    const sunday = new Date('2026-10-11T15:00:00.000Z');
    const cycle = buildInitialWeeklyCycle(sunday, 'America/Sao_Paulo');

    expect(cycle.endsAt.toISOString()).toBe('2026-10-12T03:00:00.000Z');
    expect(cycle.referenceWeek).toBe('2026-10-05');
  });

  it('uses the local weekday, not the UTC one, near midnight', () => {
    // Domingo 23:30 em São Paulo já é segunda 02:30 UTC.
    const sundayNightLocal = new Date('2026-10-12T02:30:00.000Z');
    const cycle = buildInitialWeeklyCycle(sundayNightLocal, 'America/Sao_Paulo');

    expect(cycle.endsAt.toISOString()).toBe('2026-10-12T03:00:00.000Z');
  });

  it('keeps the end strictly after the start', () => {
    const justAfterMidnight = new Date('2026-10-12T03:00:00.000Z');
    const cycle = buildInitialWeeklyCycle(justAfterMidnight, 'America/Sao_Paulo');

    expect(cycle.endsAt.getTime()).toBeGreaterThan(cycle.startsAt.getTime());
    expect(cycle.endsAt.toISOString()).toBe('2026-10-19T03:00:00.000Z');
  });
});
