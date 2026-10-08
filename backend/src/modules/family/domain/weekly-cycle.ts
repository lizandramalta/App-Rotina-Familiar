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

/**
 * Ciclo inicial da família (SPEC-002 §3.1): começa no instante da criação e
 * termina na próxima segunda-feira 00:00 no fuso da família, estritamente
 * futura. Criar numa segunda-feira, portanto, encerra na segunda seguinte.
 */
export function buildInitialWeeklyCycle(now: Date, timeZoneId: string): InitialWeeklyCycle {
  const local = toLocalDateTime(now, timeZoneId);

  // Operar sobre a data civil em UTC evita que somar dias atravesse uma mudança
  // de horário e erre o dia.
  const civilDay = Date.UTC(local.year, local.month - 1, local.day);

  const daysSinceMonday = (local.weekday + 6) % 7;
  const daysUntilNextMonday = 7 - daysSinceMonday;

  const nextMonday = new Date(civilDay + daysUntilNextMonday * DAY_MS);
  const monday = new Date(civilDay - daysSinceMonday * DAY_MS);

  return {
    startsAt: now,
    endsAt: startOfLocalDay(
      {
        year: nextMonday.getUTCFullYear(),
        month: nextMonday.getUTCMonth() + 1,
        day: nextMonday.getUTCDate(),
      },
      timeZoneId,
    ),
    timeZoneId,
    referenceWeek: formatDate(
      monday.getUTCFullYear(),
      monday.getUTCMonth() + 1,
      monday.getUTCDate(),
    ),
  };
}
