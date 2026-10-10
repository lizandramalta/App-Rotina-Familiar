import { nextWeekStart, referenceWeekOf } from './weekly-cycle.js';

export const TimeZoneApplication = {
  IMMEDIATE: 'immediate',
  NEXT_CYCLE: 'nextCycle',
} as const;

export type TimeZoneApplication = (typeof TimeZoneApplication)[keyof typeof TimeZoneApplication];

export function isTimeZoneApplication(candidate: unknown): candidate is TimeZoneApplication {
  return (
    candidate === TimeZoneApplication.IMMEDIATE || candidate === TimeZoneApplication.NEXT_CYCLE
  );
}

/** Limites de um ciclo semanal: início inclusivo, fim exclusivo. */
export interface CycleLimits {
  readonly startsAt: Date;
  readonly endsAt: Date;
  readonly timeZoneId: string;
  readonly isTransition: boolean;
}

export interface NewCycle extends CycleLimits {
  readonly referenceWeek: string;
}

export interface ScheduledChange {
  readonly id: string;
  readonly timeZoneId: string;
  /** Encerramento do ciclo em que a alteração foi programada. */
  readonly effectiveAt: Date;
}

export interface SettledCycles {
  /** Ciclos contíguos a persistir para alcançar o instante atual, em ordem. */
  readonly created: readonly NewCycle[];
  /** Ciclo aberto depois da liquidação (o último criado ou o original). */
  readonly open: CycleLimits;
  readonly familyTimeZoneId: string;
  /** A alteração programada entrou em vigor durante a liquidação. */
  readonly appliedScheduledId: string | undefined;
}

/**
 * Liquida os ciclos vencidos (BA-13, decisão E-07). Não existe worker de
 * apuração nesta entrega, então o ciclo aberto pode já ter terminado quando a
 * família é lida ou alterada. Cria os ciclos contíguos que faltam — sem apurar
 * destaque — e faz a alteração programada entrar no primeiro ciclo que começa
 * em ou depois do seu `effectiveAt`.
 *
 * Função pura: a prévia a usa em memória, sem gravar nada.
 */
export function settleCycles(input: {
  readonly open: CycleLimits;
  readonly familyTimeZoneId: string;
  readonly scheduled: ScheduledChange | undefined;
  readonly now: Date;
}): SettledCycles {
  const created: NewCycle[] = [];
  let open = input.open;
  let familyTimeZoneId = input.familyTimeZoneId;
  let appliedScheduledId: string | undefined;

  while (open.endsAt.getTime() <= input.now.getTime()) {
    const startsAt = open.endsAt;
    let timeZoneId = open.timeZoneId;
    let isTransition = false;

    if (
      input.scheduled !== undefined &&
      appliedScheduledId === undefined &&
      input.scheduled.effectiveAt.getTime() <= startsAt.getTime()
    ) {
      timeZoneId = input.scheduled.timeZoneId;
      familyTimeZoneId = timeZoneId;
      appliedScheduledId = input.scheduled.id;
      isTransition = true;
    }

    const next: NewCycle = {
      startsAt,
      endsAt: nextWeekStart(startsAt, timeZoneId),
      timeZoneId,
      isTransition,
      referenceWeek: referenceWeekOf(startsAt, timeZoneId),
    };

    created.push(next);
    open = next;
  }

  return { created, open, familyTimeZoneId, appliedScheduledId };
}

export interface TimeZoneChangePlan {
  readonly application: TimeZoneApplication;
  readonly timeZoneId: string;
  /** Instante em que o novo fuso passa a valer. */
  readonly effectiveAt: Date;
  /**
   * `immediate`: o ciclo aberto, com o mesmo início e novo fim. `nextCycle`: o
   * primeiro ciclo no novo fuso, que começa no encerramento do atual.
   */
  readonly effectiveLimits: CycleLimits;
}

/**
 * Calcula os limites efetivos de uma mudança sobre o ciclo aberto já liquidado
 * (CA-06, CA-07). Toda mudança de fuso é uma transição excepcional: o período
 * deixa de ser o de uma semana civil comum (CA-08).
 */
export function planTimeZoneChange(input: {
  readonly open: CycleLimits;
  readonly timeZoneId: string;
  readonly application: TimeZoneApplication;
  readonly now: Date;
}): TimeZoneChangePlan {
  if (input.application === TimeZoneApplication.IMMEDIATE) {
    return {
      application: input.application,
      timeZoneId: input.timeZoneId,
      effectiveAt: input.now,
      effectiveLimits: {
        // Início preservado: o que já foi creditado no ciclo continua nele.
        startsAt: input.open.startsAt,
        endsAt: nextWeekStart(input.now, input.timeZoneId),
        timeZoneId: input.timeZoneId,
        isTransition: true,
      },
    };
  }

  const startsAt = input.open.endsAt;

  return {
    application: input.application,
    timeZoneId: input.timeZoneId,
    effectiveAt: startsAt,
    effectiveLimits: {
      startsAt,
      endsAt: nextWeekStart(startsAt, input.timeZoneId),
      timeZoneId: input.timeZoneId,
      isTransition: true,
    },
  };
}
