import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  FamilyProfile,
  FamilyProfileRepositoryPort,
} from '../application/family-profile-repository-port.js';

interface FamilyRow {
  id: string;
  name: string;
  timezone: string;
}
function toProfile(row: FamilyRow): FamilyProfile {
  return { id: row.id, name: row.name, timeZoneId: row.timezone };
}

export class PostgresFamilyProfileRepository implements FamilyProfileRepositoryPort {
  public async findFamily(
    tx: TransactionContext,
    familyId: string,
  ): Promise<FamilyProfile | undefined> {
    const result = await asPostgresClient(tx).query<FamilyRow>(
      `select id, name, timezone from app.families where id = $1`,
      [familyId],
    );
    return result.rows[0] === undefined ? undefined : toProfile(result.rows[0]);
  }
  public async lockFamily(
    tx: TransactionContext,
    familyId: string,
  ): Promise<FamilyProfile | undefined> {
    const result = await asPostgresClient(tx).query<FamilyRow>(
      `select id, name, timezone from app.families where id = $1 for update`,
      [familyId],
    );
    return result.rows[0] === undefined ? undefined : toProfile(result.rows[0]);
  }
  public async findActorRole(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
  ): Promise<MemberRole | undefined> {
    const result = await asPostgresClient(tx).query<{ role: string }>(
      `select role from app.members where family_id = $1 and id = $2`,
      [familyId, memberId],
    );
    const role = result.rows[0]?.role;
    return role !== undefined && isValidMemberRole(role) ? role : undefined;
  }
  public async updateName(
    tx: TransactionContext,
    familyId: string,
    name: string,
    now: Date,
  ): Promise<FamilyProfile> {
    const result = await asPostgresClient(tx).query<FamilyRow>(
      `update app.families set name = $2, updated_at = $3 where id = $1
       returning id, name, timezone`,
      [familyId, name, now],
    );
    if (result.rows[0] === undefined) throw new TypeError('Family update returned no row.');
    return toProfile(result.rows[0]);
  }
}
