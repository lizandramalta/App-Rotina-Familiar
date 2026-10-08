export const DEFAULT_TIME_ZONE_ID = 'America/Sao_Paulo';

/**
 * Forma de um identificador IANA (`Area/Location`, ou nomes simples como
 * `UTC`). Recusa deslocamentos como `+03:00`, que o `Intl` aceita mas não são
 * identificadores IANA.
 */
const IANA_SHAPE = /^[A-Za-z][A-Za-z0-9_+-]*(?:\/[A-Za-z0-9_+-]+)*$/;

export function isValidTimeZoneId(candidate: string): boolean {
  if (!IANA_SHAPE.test(candidate)) {
    return false;
  }

  try {
    new Intl.DateTimeFormat('en-US', { timeZone: candidate });
    return true;
  } catch {
    return false;
  }
}

interface LocalDateTime {
  readonly year: number;
  readonly month: number;
  readonly day: number;
  readonly hour: number;
  readonly minute: number;
  readonly second: number;
  /** 0 = domingo ... 6 = sábado. */
  readonly weekday: number;
}

const WEEKDAY_INDEX: Readonly<Record<string, number>> = {
  Sun: 0,
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
};

export function toLocalDateTime(instant: Date, timeZoneId: string): LocalDateTime {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timeZoneId,
    hourCycle: 'h23',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    weekday: 'short',
  }).formatToParts(instant);

  const read = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((part) => part.type === type)?.value ?? '';

  return {
    year: Number(read('year')),
    month: Number(read('month')),
    day: Number(read('day')),
    hour: Number(read('hour')),
    minute: Number(read('minute')),
    second: Number(read('second')),
    weekday: WEEKDAY_INDEX[read('weekday')] ?? 0,
  };
}

/** Deslocamento do fuso em ms no instante dado (positivo a leste de UTC). */
function offsetMs(instant: Date, timeZoneId: string): number {
  const local = toLocalDateTime(instant, timeZoneId);
  const asUtc = Date.UTC(
    local.year,
    local.month - 1,
    local.day,
    local.hour,
    local.minute,
    local.second,
  );
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/**
 * Primeiro instante válido da data civil no fuso (00:00 local). Quando a
 * meia-noite não existe por mudança de horário, devolve o primeiro instante
 * existente da data (backend-architecture.md §12).
 */
export function startOfLocalDay(
  date: { readonly year: number; readonly month: number; readonly day: number },
  timeZoneId: string,
): Date {
  const wallClockAsUtc = Date.UTC(date.year, date.month - 1, date.day);

  let candidate = new Date(wallClockAsUtc - offsetMs(new Date(wallClockAsUtc), timeZoneId));
  // Um segundo passo corrige o deslocamento quando ele muda entre a estimativa
  // e o instante real.
  candidate = new Date(wallClockAsUtc - offsetMs(candidate, timeZoneId));

  const local = toLocalDateTime(candidate, timeZoneId);
  const landedOnDate =
    local.year === date.year && local.month === date.month && local.day === date.day;

  if (landedOnDate && local.hour === 0 && local.minute === 0) {
    return candidate;
  }

  // Meia-noite inexistente: avança em passos de minuto até o primeiro instante
  // que já pertence à data.
  let probe = new Date(candidate.getTime() - 3 * 60 * 60 * 1000);
  const limit = candidate.getTime() + 3 * 60 * 60 * 1000;
  while (probe.getTime() <= limit) {
    const probeLocal = toLocalDateTime(probe, timeZoneId);
    if (
      probeLocal.year === date.year &&
      probeLocal.month === date.month &&
      probeLocal.day === date.day
    ) {
      return probe;
    }
    probe = new Date(probe.getTime() + 60 * 1000);
  }

  return candidate;
}
