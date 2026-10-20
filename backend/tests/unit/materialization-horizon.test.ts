/** Horizonte de materialização: fim do mês seguinte no fuso da família (SPEC-008 RN14). */
import { describe, expect, it } from 'vitest';
import { materializationHorizon } from '../../src/modules/routines/domain/materialization-horizon.js';

describe('materializationHorizon', () => {
  it('returns the last day of next month for a mid-month instant', () => {
    expect(materializationHorizon(new Date('2026-10-15T12:00:00Z'), 'America/Sao_Paulo')).toBe(
      '2026-11-30',
    );
  });

  it('rolls the year over when the current month is December', () => {
    // 2026-12-31T23:30:00-03:00 local, ainda dezembro no fuso da família.
    expect(materializationHorizon(new Date('2027-01-01T02:30:00Z'), 'America/Sao_Paulo')).toBe(
      '2027-01-31',
    );
  });

  it('accounts for the civil date in the family timezone, not UTC, at the year boundary', () => {
    // Mesmo instante: em UTC já é 1º de janeiro (mês seguinte = fevereiro);
    // em America/Sao_Paulo (UTC-3) ainda é 31 de dezembro (mês seguinte = janeiro).
    const instant = new Date('2027-01-01T02:30:00Z');

    expect(materializationHorizon(instant, 'UTC')).toBe('2027-02-28');
    expect(materializationHorizon(instant, 'America/Sao_Paulo')).toBe('2027-01-31');
  });

  it('resolves a leap-year February as the next month correctly', () => {
    expect(materializationHorizon(new Date('2028-01-15T12:00:00Z'), 'America/Sao_Paulo')).toBe(
      '2028-02-29',
    );
  });

  it('resolves a non-leap-year February correctly', () => {
    expect(materializationHorizon(new Date('2026-01-15T12:00:00Z'), 'America/Sao_Paulo')).toBe(
      '2026-02-28',
    );
  });
});
