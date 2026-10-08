import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { FamilySettingsRepositoryPort } from '../application/family-settings-repository-port.js';
import type {
  CycleLimits,
  NewCycle,
  ScheduledChange,
  TimeZoneApplication,
} from '../domain/time-zone-change-planner.js';

interface CycleRow {
  starts_at: Date;
  ends_at: Date;
  time_zone: string;
  in_transition: boolean;
}

interface ScheduledRow {
  id: string;
  to_time_zone: string;
  effective_at: Date;
}

const APPLICATION_COLUMN: Readonly<Record<TimeZoneApplication, string>> = {
  immediate: 'IMMEDIATE',
  nextCycle: 'NEXT_CYCLE',
};

/**
 * Adaptador PostgreSQL das configurações de fuso. Queries parametrizadas sobre o
 * client da transação em curso; toda consulta é escopada pela família.
 */
export class PostgresFamilySettingsRepository implements FamilySettingsRepositoryPort {
  public async findMemberRole(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<MemberRole | undefined> {
    const result = await asPostgresClient(tx).query<{ role: string }>(
      `select role from app.members where family_id = $1 and id = $2`,
      [params.familyId, params.memberId],
    );

    const role = result.rows[0]?.role;
    return role !== undefined && isValidMemberRole(role) ? role : undefined;
  }

  public async findFamilyTimeZone(
    tx: TransactionContext,
    familyId: string,
  ): Promise<string | undefined> {
    const result = await asPostgresClient(tx).query<{ timezone: string }>(
      `select timezone from app.families where id = $1`,
      [familyId],
    );

    return result.rows[0]?.timezone;
  }

  public async findOpenCycle(
    tx: TransactionContext,
    familyId: string,
  ): Promise<CycleLimits | undefined> {
    const result = await asPostgresClient(tx).query<CycleRow>(
      `select starts_at, ends_at, time_zone, in_transition
         from app.weekly_cycles
        where family_id = $1
        order by starts_at desc
        limit 1`,
      [familyId],
    );

    const row = result.rows[0];
    return row === undefined
      ? undefined
      : {
          startsAt: row.starts_at,
          endsAt: row.ends_at,
          timeZoneId: row.time_zone,
          isTransition: row.in_transition,
        };
  }

  public async findScheduledChange(
    tx: TransactionContext,
    familyId: string,
  ): Promise<ScheduledChange | undefined> {
    const result = await asPostgresClient(tx).query<ScheduledRow>(
      `select id, to_time_zone, effective_at
         from app.family_time_zone_changes
        where family_id = $1 and status = 'SCHEDULED'`,
      [familyId],
    );

    const row = result.rows[0];
    return row === undefined
      ? undefined
      : { id: row.id, timeZoneId: row.to_time_zone, effectiveAt: row.effective_at };
  }

  public async insertCycle(
    tx: TransactionContext,
    params: { readonly cycleId: string; readonly familyId: string; readonly cycle: NewCycle },
  ): Promise<void> {
    const { cycle } = params;

    await asPostgresClient(tx).query(
      `insert into app.weekly_cycles
         (id, family_id, starts_at, ends_at, time_zone, in_transition, reference_week)
       values ($1, $2, $3, $4, $5, $6, $7)`,
      [
        params.cycleId,
        params.familyId,
        cycle.startsAt,
        cycle.endsAt,
        cycle.timeZoneId,
        cycle.isTransition,
        cycle.referenceWeek,
      ],
    );
  }

  public async updateCycleLimits(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly startsAt: Date;
      readonly endsAt: Date;
      readonly timeZoneId: string;
      readonly isTransition: boolean;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.weekly_cycles
          set ends_at = $3, time_zone = $4, in_transition = $5
        where family_id = $1 and starts_at = $2`,
      [params.familyId, params.startsAt, params.endsAt, params.timeZoneId, params.isTransition],
    );
  }

  public async updateFamilyTimeZone(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly timeZoneId: string; readonly updatedAt: Date },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.families set timezone = $2, updated_at = $3 where id = $1`,
      [params.familyId, params.timeZoneId, params.updatedAt],
    );
  }

  public async insertChange(
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
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.family_time_zone_changes
         (id, family_id, requested_by_member_id, from_time_zone, to_time_zone,
          application, status, effective_at, requested_at, resolved_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9,
               case when $7 = 'APPLIED' then $9::timestamptz end)`,
      [
        params.changeId,
        params.familyId,
        params.requestedByMemberId,
        params.fromTimeZoneId,
        params.toTimeZoneId,
        APPLICATION_COLUMN[params.application],
        params.status,
        params.effectiveAt,
        params.requestedAt,
      ],
    );
  }

  public async resolveChange(
    tx: TransactionContext,
    params: {
      readonly changeId: string;
      readonly status: 'APPLIED' | 'SUPERSEDED';
      readonly resolvedAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.family_time_zone_changes
          set status = $2, resolved_at = $3
        where id = $1 and status = 'SCHEDULED'`,
      [params.changeId, params.status, params.resolvedAt],
    );
  }
}
