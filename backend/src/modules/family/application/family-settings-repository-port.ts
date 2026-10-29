import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';
import type {
  CycleLimits,
  NewCycle,
  ScheduledChange,
  TimeZoneApplication,
} from '../domain/time-zone-change-planner.js';

/**
 * Porta de persistência das configurações de fuso (SPEC-002 Fase 3). Toda
 * operação recebe o `TransactionContext`; as escritas rodam sob o lock da família.
 */
export interface FamilySettingsRepositoryPort {
  /** Papel atual do membro na família; `undefined` se ele não pertence a ela. */
  findMemberRole(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<MemberRole | undefined>;

  findFamilyTimeZone(tx: TransactionContext, familyId: string): Promise<string | undefined>;

  /** Ciclo aberto: o mais recente da família. */
  findOpenCycle(tx: TransactionContext, familyId: string): Promise<CycleLimits | undefined>;

  findScheduledChange(
    tx: TransactionContext,
    familyId: string,
  ): Promise<ScheduledChange | undefined>;

  insertCycle(
    tx: TransactionContext,
    params: { readonly cycleId: string; readonly familyId: string; readonly cycle: NewCycle },
  ): Promise<void>;

  /** O ciclo é identificado pelo início (`unique (family_id, starts_at)`). */
  updateCycleLimits(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly startsAt: Date;
      readonly endsAt: Date;
      readonly timeZoneId: string;
      readonly isTransition: boolean;
    },
  ): Promise<void>;

  updateFamilyTimeZone(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly timeZoneId: string; readonly updatedAt: Date },
  ): Promise<void>;

  insertChange(
    tx: TransactionContext,
    params: {
      readonly changeId: string;
      readonly familyId: string;
      readonly requestedByMemberId: string;
      readonly fromTimeZoneId: string;
      readonly toTimeZoneId: string;
      readonly application: TimeZoneApplication;
      readonly status: 'SCHEDULED' | 'APPLIED';
      readonly effectiveAt: Date;
      readonly requestedAt: Date;
    },
  ): Promise<void>;

  resolveChange(
    tx: TransactionContext,
    params: {
      readonly changeId: string;
      readonly status: 'APPLIED' | 'SUPERSEDED';
      readonly resolvedAt: Date;
    },
  ): Promise<void>;
}
