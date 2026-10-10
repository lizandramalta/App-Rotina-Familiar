import { LocalDate } from '../../../shared/domain/local-date.js';
import { ValidationError } from '../../../shared/domain/domain-error.js';

const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
const CONTROL_CHARACTERS = /\p{Cc}/u;

export function validateTaskTitle(input: unknown): string {
  if (typeof input !== 'string') {
    throw new ValidationError('Task title is required.', { title: ['TITLE_REQUIRED'] });
  }

  if (CONTROL_CHARACTERS.test(input)) {
    throw new ValidationError('Task title is invalid.', { title: ['TITLE_INVALID_LENGTH'] });
  }

  const title = input.trim();
  const length = [...graphemeSegmenter.segment(title)].length;
  if (length === 0) {
    throw new ValidationError('Task title is required.', { title: ['TITLE_REQUIRED'] });
  }
  if (length > 60) {
    throw new ValidationError('Task title is too long.', { title: ['TITLE_INVALID_LENGTH'] });
  }
  return title;
}

export function validateWeight(input: unknown): number {
  if (input === undefined || input === null) {
    throw new ValidationError('Task weight is required.', { weight: ['WEIGHT_REQUIRED'] });
  }
  if (typeof input !== 'number' || !Number.isInteger(input) || input < 1 || input > 3) {
    throw new ValidationError('Task weight must be between 1 and 3.', {
      weight: ['WEIGHT_INVALID'],
    });
  }
  return input;
}

export function validateScheduledDate(input: unknown): string {
  if (typeof input !== 'string') {
    throw new ValidationError('Scheduled date is invalid.', {
      scheduledDate: ['SCHEDULED_DATE_INVALID'],
    });
  }
  try {
    return LocalDate.parse(input).toString();
  } catch {
    throw new ValidationError('Scheduled date is invalid.', {
      scheduledDate: ['SCHEDULED_DATE_INVALID'],
    });
  }
}

export function validateNote(input: unknown): string | null {
  if (input === undefined || input === null) {
    return null;
  }
  if (typeof input !== 'string' || [...graphemeSegmenter.segment(input)].length > 250) {
    throw new ValidationError('Task note is too long.', { note: ['NOTE_TOO_LONG'] });
  }
  return input;
}

export function validateSignalResolution(
  input: unknown,
): 'resetToPending' | 'keepAwaitingConfirmation' | undefined {
  if (input === undefined) {
    return undefined;
  }
  if (input === 'resetToPending' || input === 'keepAwaitingConfirmation') {
    return input;
  }
  throw new ValidationError('Signal resolution is invalid.', {
    signalResolution: ['SIGNAL_RESOLUTION_INVALID'],
  });
}
