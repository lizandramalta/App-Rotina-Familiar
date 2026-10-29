import { LocalDate } from '../../../shared/domain/local-date.js';
import { ValidationError } from '../../../shared/domain/domain-error.js';

const VALID_FREQUENCY_DAYS = [1, 7, 14, 21, 28] as const;
export type FrequencyDays = (typeof VALID_FREQUENCY_DAYS)[number];

export function validateFrequencyDays(input: unknown): FrequencyDays {
  if (typeof input === 'number' && (VALID_FREQUENCY_DAYS as readonly number[]).includes(input)) {
    return input as FrequencyDays;
  }
  throw new ValidationError('Frequency must be 1, 7, 14, 21 or 28 days.', {
    frequencyDays: ['FREQUENCY_DAYS_INVALID'],
  });
}

export function validateStartDate(input: unknown): string {
  if (typeof input !== 'string') {
    throw new ValidationError('Start date is invalid.', {
      startDate: ['START_DATE_INVALID'],
    });
  }
  try {
    return LocalDate.parse(input).toString();
  } catch {
    throw new ValidationError('Start date is invalid.', {
      startDate: ['START_DATE_INVALID'],
    });
  }
}
