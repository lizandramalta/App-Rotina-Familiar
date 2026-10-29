const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
const CONTROL_CHARACTERS = /\p{Cc}/u;
const WHITESPACE = /\s/u;

/** Caracteres visíveis: grafemas, para que um emoji composto conte uma vez. */
function countGraphemes(value: string): number {
  let count = 0;
  for (const _segment of graphemeSegmenter.segment(value)) {
    count += 1;
  }
  return count;
}

export type NameProblem = 'REQUIRED' | 'INVALID_LENGTH' | 'INVALID_CONTENT';

export const NAME_MAX_LENGTH = 60;
export const NICKNAME_MAX_LENGTH = 20;

/**
 * Nome de membro ou de família (RF01, RF02): 1–60 caracteres Unicode visíveis
 * após trim, sem caracteres de controle. Devolve o valor normalizado ou o
 * problema, para o chamador escolher o código de campo.
 */
export function normalizeName(
  input: unknown,
): { readonly value: string } | { readonly problem: NameProblem } {
  const raw = typeof input === 'string' ? input : '';

  // O controle é checado antes do trim: `\n` nas pontas seria apagado pelo trim
  // e passaria despercebido, e o contrato é rejeitar controle em qualquer posição.
  if (CONTROL_CHARACTERS.test(raw)) {
    return { problem: 'INVALID_CONTENT' };
  }

  const value = raw.trim();
  if (value.length === 0) {
    return { problem: 'REQUIRED' };
  }

  if (countGraphemes(value) > NAME_MAX_LENGTH) {
    return { problem: 'INVALID_LENGTH' };
  }

  return { value };
}

export type NicknameProblem = 'INVALID_LENGTH' | 'INVALID_CONTENT';

/**
 * Apelido (RN63, RF48): opcional; vazio ou nulo remove a configuração. Até 20
 * caracteres não-espaço após o trim — espaços internos não contam.
 */
export function normalizeNickname(
  input: unknown,
): { readonly value: string | null } | { readonly problem: NicknameProblem } {
  if (input === undefined || input === null) {
    return { value: null };
  }

  const raw = typeof input === 'string' ? input : '';

  if (CONTROL_CHARACTERS.test(raw)) {
    return { problem: 'INVALID_CONTENT' };
  }

  const value = raw.trim();
  if (value.length === 0) {
    return { value: null };
  }

  let nonSpaceCount = 0;
  for (const segment of graphemeSegmenter.segment(value)) {
    if (!WHITESPACE.test(segment.segment)) {
      nonSpaceCount += 1;
    }
  }

  if (nonSpaceCount > NICKNAME_MAX_LENGTH) {
    return { problem: 'INVALID_LENGTH' };
  }

  return { value };
}
