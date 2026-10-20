/** Validações de rotina (SPEC-008 §5.1, CA-02). */
import { describe, expect, it } from 'vitest';
import {
  validateFrequencyDays,
  validateStartDate,
} from '../../src/modules/routines/domain/routine-validation.js';
import { ValidationError } from '../../src/shared/domain/domain-error.js';

describe('validateFrequencyDays', () => {
  it.each([1, 7, 14, 21, 28])('accepts %d as a valid frequency', (value) => {
    expect(validateFrequencyDays(value)).toBe(value);
  });

  it.each([[0], [2], [30], ['7'], [null], [undefined], [7.5]])(
    'CA-02 rejects anything outside 1/7/14/21/28 (rejects %j) with FREQUENCY_DAYS_INVALID',
    (value) => {
      const error = (() => {
        try {
          validateFrequencyDays(value);
          return undefined;
        } catch (e) {
          return e;
        }
      })();

      expect(error).toBeInstanceOf(ValidationError);
      expect((error as ValidationError).fieldErrors).toEqual({
        frequencyDays: ['FREQUENCY_DAYS_INVALID'],
      });
    },
  );
});

describe('validateStartDate', () => {
  it('accepts a valid civil date and returns it unchanged', () => {
    expect(validateStartDate('2026-10-10')).toBe('2026-10-10');
  });

  it('accepts a start date in the past', () => {
    expect(validateStartDate('2020-01-01')).toBe('2020-01-01');
  });

  it.each([['not-a-date'], ['2026-13-01'], ['2026-02-30'], [null], [undefined], [20261010]])(
    'CA-02 rejects an invalid civil date (rejects %j) with START_DATE_INVALID',
    (value) => {
      const error = (() => {
        try {
          validateStartDate(value);
          return undefined;
        } catch (e) {
          return e;
        }
      })();

      expect(error).toBeInstanceOf(ValidationError);
      expect((error as ValidationError).fieldErrors).toEqual({
        startDate: ['START_DATE_INVALID'],
      });
    },
  );
});
