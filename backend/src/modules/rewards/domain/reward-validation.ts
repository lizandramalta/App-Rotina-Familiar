import { ValidationError } from '../../../shared/domain/domain-error.js';

const CONTROL_CHARACTER = /\p{Cc}/u;
const WHITESPACE = /\s/u;

/** SPEC-015 CA-03/04: trim, até 60 caracteres não-espaço e chave case-insensitive. */
export function validateRewardTitle(input: unknown): { title: string; normalizedTitle: string } {
  if (typeof input !== 'string' || input.trim().length === 0) {
    throw new ValidationError('Reward title is required.', { title: ['REWARD_TITLE_REQUIRED'] });
  }
  if (CONTROL_CHARACTER.test(input)) {
    throw new ValidationError('Reward title contains control characters.', {
      title: ['REWARD_TITLE_CONTROL_CHARACTERS'],
    });
  }
  const title = input.trim();
  if ([...title].filter((character) => !WHITESPACE.test(character)).length > 60) {
    throw new ValidationError('Reward title is too long.', {
      title: ['REWARD_TITLE_TOO_LONG'],
    });
  }
  return { title, normalizedTitle: title.toLowerCase() };
}

/** SPEC-015 CA-02/03: descrição opcional, com espaços contabilizados. */
export function validateRewardDetails(input: unknown): string | null {
  if (input === undefined) return null;
  if (typeof input !== 'string' || [...input].length > 255) {
    throw new ValidationError('Reward details are too long.', {
      details: ['REWARD_DETAILS_TOO_LONG'],
    });
  }
  return input;
}
