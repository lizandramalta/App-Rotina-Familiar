import { ValidationError } from '../../../shared/domain/domain-error.js';
import { MissionTasksRequiredError, TaskNotInFamilyError } from './mission-errors.js';

const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
const CONTROL_CHARACTERS = /\p{Cc}/u;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MISSION_NOTE_MAX_LENGTH = 250;
export const MISSION_TITLE_MAX_LENGTH = 60;

function graphemeCount(value: string): number {
  return [...graphemeSegmenter.segment(value)].length;
}

/** SPEC-014 E-01: 1 a 60 caracteres visíveis após trim, sem controle. */
export function validateMissionTitle(input: unknown): string {
  if (typeof input !== 'string') {
    throw new ValidationError('Mission title is required.', { title: ['TITLE_REQUIRED'] });
  }
  if (CONTROL_CHARACTERS.test(input)) {
    throw new ValidationError('Mission title is invalid.', { title: ['TITLE_INVALID_LENGTH'] });
  }
  const title = input.trim();
  const length = graphemeCount(title);
  if (length === 0) {
    throw new ValidationError('Mission title is required.', { title: ['TITLE_REQUIRED'] });
  }
  if (length > MISSION_TITLE_MAX_LENGTH) {
    throw new ValidationError('Mission title is too long.', { title: ['TITLE_INVALID_LENGTH'] });
  }
  return title;
}

/** RN68/RF71: até 250 caracteres; `null` ou ausência removem a observação. */
export function validateMissionNote(input: unknown): string | null {
  if (input === undefined || input === null) {
    return null;
  }
  if (typeof input !== 'string' || graphemeCount(input) > MISSION_NOTE_MAX_LENGTH) {
    throw new ValidationError('Mission note is too long.', { note: ['NOTE_TOO_LONG'] });
  }
  return input;
}

/**
 * Normaliza `taskIds` na criação: ausente ou vazio é `MISSION_TASKS_REQUIRED`;
 * ids duplicados são deduplicados. Um id malformado nunca pode existir na
 * família, então responde como `TASK_NOT_IN_FAMILY` sem expor o motivo.
 */
export function normalizeTaskIds(input: unknown): readonly string[] {
  if (!Array.isArray(input) || input.length === 0) {
    throw new MissionTasksRequiredError();
  }
  if (input.some((id) => typeof id !== 'string' || !UUID_PATTERN.test(id))) {
    throw new TaskNotInFamilyError();
  }
  return [...new Set((input as string[]).map((id) => id.toLowerCase()))];
}
