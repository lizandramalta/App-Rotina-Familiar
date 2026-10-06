import { describe, it, expect } from 'vitest';
import { LocalDate } from '../../src/shared/domain/local-date.js';
import { ValidationError } from '../../src/shared/domain/domain-error.js';

describe('LocalDate Value Object', () => {
  it('parses valid dates correctly', () => {
    const date = LocalDate.parse('2026-10-06');
    expect(date.toString()).toBe('2026-10-06');
    expect(date.toJSON()).toBe('2026-10-06');
  });

  it('correctly compares equal dates', () => {
    const d1 = LocalDate.parse('2026-10-06');
    const d2 = LocalDate.parse('2026-10-06');
    expect(d1.equals(d2)).toBe(true);
  });

  it('rejects invalid date formats', () => {
    expect(() => LocalDate.parse('06-10-2026')).toThrow(ValidationError);
    expect(() => LocalDate.parse('2026/10/06')).toThrow(ValidationError);
    expect(() => LocalDate.parse('invalid')).toThrow(ValidationError);
  });

  it('rejects non-existent days in month', () => {
    expect(() => LocalDate.parse('2026-02-30')).toThrow(ValidationError);
    expect(() => LocalDate.parse('2026-04-31')).toThrow(ValidationError);
  });

  it('handles leap years accurately', () => {
    // 2024 was a leap year
    expect(LocalDate.isValid('2024-02-29')).toBe(true);
    // 2026 is not a leap year
    expect(LocalDate.isValid('2026-02-29')).toBe(false);
  });
});
