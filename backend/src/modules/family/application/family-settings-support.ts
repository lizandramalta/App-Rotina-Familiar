import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import {
  isTimeZoneApplication,
  settleCycles,
  type CycleLimits,
  type ScheduledChange,
  type SettledCycles,
  type TimeZoneApplication,
} from '../domain/time-zone-change-planner.js';
import { isValidTimeZoneId } from '../domain/time-zone.js';
import type { CycleLimitsView, FamilySettingsView } from './family-settings-dto.js';
import type { FamilySettingsRepositoryPort } from './family-settings-repository-port.js';

/** Estado da família com os ciclos vencidos já liquidados, ainda só em memória. */
export interface SettledFamilyState {
  readonly settled: SettledCycles;
  /** Programada que continua pendente depois da liquidação. */
  readonly pendingScheduled: ScheduledChange | undefined;
}

/** Atalho antes do lock: quem não é Administrador nem espera na fila da família. */
export function assertAdministratorRole(actor: ActorContext): void {
  if (actor.role !== MemberRole.ADMINISTRATOR) {
    throw new ActionNotAllowedError();
  }
}

/**
 * Autoridade real: o papel é relido no banco dentro da transação (RNF07), porque
 * a sessão pode ter esperado o lock enquanto o perfil era rebaixado.
 */
export async function loadSettledState(
  repository: FamilySettingsRepositoryPort,
  tx: TransactionContext,
  actor: ActorContext,
  now: Date,
): Promise<SettledFamilyState> {
  const role = await repository.findMemberRole(tx, {
    familyId: actor.familyId,
    memberId: actor.memberId,
  });

  if (role === undefined) {
    throw new NotFoundError('Family not found.');
  }

  if (role !== MemberRole.ADMINISTRATOR) {
    throw new ActionNotAllowedError();
  }

  // Em série: uma transação usa um único client e não admite queries concorrentes.
  const familyTimeZoneId = await repository.findFamilyTimeZone(tx, actor.familyId);
  const open = await repository.findOpenCycle(tx, actor.familyId);
  const scheduled = await repository.findScheduledChange(tx, actor.familyId);

  if (familyTimeZoneId === undefined || open === undefined) {
    throw new NotFoundError('Family not found.');
  }

  const settled = settleCycles({ open, familyTimeZoneId, scheduled, now });

  return {
    settled,
    pendingScheduled: settled.appliedScheduledId === undefined ? scheduled : undefined,
  };
}

/** Grava os ciclos vencidos e a entrada em vigor da programada, se houve. */
export async function persistSettlement(
  deps: {
    readonly repository: FamilySettingsRepositoryPort;
    readonly newId: () => string;
  },
  tx: TransactionContext,
  actor: ActorContext,
  state: SettledFamilyState,
  now: Date,
): Promise<void> {
  const { repository, newId } = deps;

  for (const cycle of state.settled.created) {
    await repository.insertCycle(tx, { cycleId: newId(), familyId: actor.familyId, cycle });
  }

  if (state.settled.appliedScheduledId !== undefined) {
    await repository.updateFamilyTimeZone(tx, {
      familyId: actor.familyId,
      timeZoneId: state.settled.familyTimeZoneId,
      updatedAt: now,
    });
    await repository.resolveChange(tx, {
      changeId: state.settled.appliedScheduledId,
      status: 'APPLIED',
      resolvedAt: now,
    });
  }
}

export function toLimitsView(limits: CycleLimits): CycleLimitsView {
  return {
    startsAt: limits.startsAt.toISOString(),
    endsAt: limits.endsAt.toISOString(),
    timeZoneId: limits.timeZoneId,
    isTransition: limits.isTransition,
  };
}

export function toSettingsView(
  state: SettledFamilyState,
  override?: {
    readonly timeZoneId: string;
    readonly open: CycleLimits;
    readonly scheduled: ScheduledChange | undefined;
  },
): FamilySettingsView {
  const scheduled = override === undefined ? state.pendingScheduled : override.scheduled;
  const open = override === undefined ? state.settled.open : override.open;

  return {
    timeZoneId: override === undefined ? state.settled.familyTimeZoneId : override.timeZoneId,
    scheduledTimeZoneChange:
      scheduled === undefined
        ? null
        : { timeZoneId: scheduled.timeZoneId, effectiveAt: scheduled.effectiveAt.toISOString() },
    limits: toLimitsView(open),
  };
}

export interface ValidatedTimeZoneChange {
  readonly timeZoneId: string;
  readonly application: TimeZoneApplication;
}

export function validateTimeZoneChange(input: {
  readonly timeZoneId: unknown;
  readonly application: unknown;
}): ValidatedTimeZoneChange {
  const fieldErrors: Record<string, string[]> = {};

  if (typeof input.timeZoneId !== 'string' || !isValidTimeZoneId(input.timeZoneId)) {
    fieldErrors['timeZoneId'] = ['TIME_ZONE_ID_INVALID'];
  }

  if (!isTimeZoneApplication(input.application)) {
    fieldErrors['application'] = ['TIME_ZONE_APPLICATION_INVALID'];
  }

  if (
    Object.keys(fieldErrors).length > 0 ||
    typeof input.timeZoneId !== 'string' ||
    !isTimeZoneApplication(input.application)
  ) {
    throw new ValidationError('The request contains invalid values.', fieldErrors);
  }

  return { timeZoneId: input.timeZoneId, application: input.application };
}

/** Fuso igual ao vigente não é mudança (decisão E-09). */
export function assertTimeZoneDiffers(requested: string, current: string): void {
  if (requested === current) {
    throw new ValidationError('The requested time zone is already in effect.', {
      timeZoneId: ['TIME_ZONE_UNCHANGED'],
    });
  }
}

/**
 * Erro de domínio sobe como está. Qualquer outra falha (banco, conexão) deixa o
 * commit incerto: responde 503 sem afirmar reversão (CA-09, RNF12).
 */
export async function guardPersistence<T>(
  logger: Logger,
  event: string,
  work: () => Promise<T>,
): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) {
      throw error;
    }

    logger.error(event, error);
    throw new DependencyUnavailableError();
  }
}
