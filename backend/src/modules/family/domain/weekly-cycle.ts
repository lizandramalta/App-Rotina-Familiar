import { startOfLocalDay, toLocalDateTime } from './time-zone.js';

export interface InitialWeeklyCycle {
  readonly startsAt: Date;
  readonly endsAt: Date;
  readonly timeZoneId: string;
  /** Segunda-feira (data civil, `YYYY-MM-DD`) da semana em que o ciclo começa. */
  readonly referenceWeek: string;
}

const DAY_MS = 24 * 60 * 60 * 1000;

function formatDate(year: number, month: number, day: number): string {
  return [
    String(year).padStart(4, '0'),
    String(month).padStart(2, '0'),
    String(day).padStart(2, '0'),
  ].join('-');
}

interface CivilWeek {
  readonly monday: Date;
  readonly nextMonday: Date;
}

function civilWeekOf(instant: Date, timeZoneId: string): CivilWeek {
  const local = toLocalDateTime(instant, timeZoneId);

  // Operar sobre a data civil em UTC evita que somar dias atravesse uma mudança
  // de horário e erre o dia.
  const civilDay = Date.UTC(local.year, local.month - 1, local.day);

  const daysSinceMonday = (local.weekday + 6) % 7;
  const daysUntilNextMonday = 7 - daysSinceMonday;

  return {
    monday: new Date(civilDay - daysSinceMonday * DAY_MS),
    nextMonday: new Date(civilDay + daysUntilNextMonday * DAY_MS),
  };
}

/**
 * Primeira segunda-feira 00:00 no fuso, estritamente posterior ao instante. Um
 * instante que já é segunda 00:00 local encerra na segunda seguinte.
 */
export function nextWeekStart(instant: Date, timeZoneId: string): Date {
  const { nextMonday } = civilWeekOf(instant, timeZoneId);

  return startOfLocalDay(
    {
      year: nextMonday.getUTCFullYear(),
      month: nextMonday.getUTCMonth() + 1,
      day: nextMonday.getUTCDate(),
    },
    timeZoneId,
  );
}

/** Segunda-feira (`YYYY-MM-DD`) da semana civil do instante no fuso. */
export function referenceWeekOf(instant: Date, timeZoneId: string): string {
  const { monday } = civilWeekOf(instant, timeZoneId);
  return formatDate(monday.getUTCFullYear(), monday.getUTCMonth() + 1, monday.getUTCDate());
}

/**
 * Ciclo inicial da família (SPEC-002 §3.1): começa no instante da criação e
 * termina na próxima segunda-feira 00:00 no fuso da família, estritamente
 * futura. Criar numa segunda-feira, portanto, encerra na segunda seguinte.
 */
export function buildInitialWeeklyCycle(now: Date, timeZoneId: string): InitialWeeklyCycle {
  return {
    startsAt: now,
    endsAt: nextWeekStart(now, timeZoneId),
    timeZoneId,
    referenceWeek: referenceWeekOf(now, timeZoneId),
  };
}
