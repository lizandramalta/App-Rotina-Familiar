import { toLocalDateTime } from '../../family/domain/time-zone.js';

function formatDate(year: number, month: number, day: number): string {
  return [
    String(year).padStart(4, '0'),
    String(month).padStart(2, '0'),
    String(day).padStart(2, '0'),
  ].join('-');
}

/**
 * Fim do mês seguinte, como data civil (`YYYY-MM-DD`), no fuso da família
 * (SPEC-008 RN14): o horizonte até onde a materialização deve alcançar.
 *
 * `toLocalDateTime` já resolve a data civil correta do instante no fuso; a
 * aritmética de calendário em seguida roda inteiramente em UTC (mesmo truque
 * de `LocalDate`/`weekly-cycle`), por isso a mudança de horário do fuso não
 * afeta o resultado.
 */
export function materializationHorizon(now: Date, timeZoneId: string): string {
  const local = toLocalDateTime(now, timeZoneId);
  // Dia 0 do mês `local.month + 1` (1-indexado) é o último dia do mês seguinte
  // ao atual — mesma técnica usada em `LocalDate.parse` para dias no mês.
  const lastDayOfNextMonth = new Date(Date.UTC(local.year, local.month + 1, 0));
  return formatDate(
    lastDayOfNextMonth.getUTCFullYear(),
    lastDayOfNextMonth.getUTCMonth() + 1,
    lastDayOfNextMonth.getUTCDate(),
  );
}
