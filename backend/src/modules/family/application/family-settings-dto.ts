import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TimeZoneApplication } from '../domain/time-zone-change-planner.js';

/** Limites de ciclo no transporte: instantes ISO 8601 UTC (BA-13). */
export interface CycleLimitsView {
  readonly startsAt: string;
  readonly endsAt: string;
  readonly timeZoneId: string;
  readonly isTransition: boolean;
}

export interface FamilySettingsView {
  readonly timeZoneId: string;
  readonly scheduledTimeZoneChange: {
    readonly timeZoneId: string;
    readonly effectiveAt: string;
  } | null;
  readonly limits: CycleLimitsView;
}

export interface TimeZoneChangePreviewView {
  readonly proposedTimeZoneId: string;
  readonly application: TimeZoneApplication;
  readonly effectiveAt: string;
  readonly effectiveLimits: CycleLimitsView;
  readonly isTransition: boolean;
}

export interface GetFamilySettingsCommand {
  readonly actor: ActorContext;
}

/**
 * Entrada de preview/confirmação. Os campos chegam como `unknown`: a validação
 * semântica (e o código de campo) é do caso de uso, que responde
 * `422 VALIDATION_FAILED` (SPEC-002 §5.3). `familyId` e papel não existem aqui.
 */
export interface ChangeFamilyTimeZoneCommand {
  readonly actor: ActorContext;
  readonly timeZoneId: unknown;
  readonly application: unknown;
}
