import { ValidationError } from './domain-error.js';

const LOCAL_DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Value object representing a civil calendar date (YYYY-MM-DD).
 *
 * Distinct from an instant in time (UTC ISO 8601), avoiding timezone offset shifts.
 */
export class LocalDate {
  private readonly value: string;

  private constructor(value: string) {
    this.value = value;
  }

  public static parse(input: string): LocalDate {
    if (!LOCAL_DATE_REGEX.test(input)) {
      throw new ValidationError(`Invalid date format. Expected YYYY-MM-DD, received: ${input}`);
    }

    const [yearStr, monthStr, dayStr] = input.split('-');
    const year = Number(yearStr);
    const month = Number(monthStr);
    const day = Number(dayStr);

    if (month < 1 || month > 12) {
      throw new ValidationError(`Invalid month: ${monthStr}`);
    }

    // Days in month validation (accounting for leap years)
    const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
    if (day < 1 || day > daysInMonth) {
      throw new ValidationError(
        `Invalid day: ${dayStr} for month: ${monthStr} and year: ${yearStr}`,
      );
    }

    return new LocalDate(input);
  }

  public static isValid(input: string): boolean {
    try {
      LocalDate.parse(input);
      return true;
    } catch {
      return false;
    }
  }

  public toString(): string {
    return this.value;
  }

  public toJSON(): string {
    return this.value;
  }

  public equals(other: LocalDate): boolean {
    return this.value === other.value;
  }
}
