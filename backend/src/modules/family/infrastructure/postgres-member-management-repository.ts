import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, type MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  MemberManagementRepositoryPort,
  MemberPageCursor,
  MemberRecord,
} from '../application/member-management-repository-port.js';

interface MemberRow {
  id: string;
  display_name: string;
  role: string;
  is_family_creator: boolean;
  created_at: Date;
}

function toRecord(row: MemberRow): MemberRecord {
  if (!isValidMemberRole(row.role)) {
    throw new TypeError('A persisted member has an invalid role.');
  }
  return {
    id: row.id,
    name: row.display_name,
    role: row.role,
    isFamilyCreator: row.is_family_creator,
    createdAt: row.created_at,
  };
}

/** Consultas parametrizadas, ordenadas e sempre delimitadas pela família da sessão. */
export class PostgresMemberManagementRepository implements MemberManagementRepositoryPort {
  public async findMembersPage(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly after: MemberPageCursor | undefined;
      readonly limit: number;
    },
  ): Promise<readonly MemberRecord[]> {
    const result = await asPostgresClient(tx).query<MemberRow>(
      `select id, display_name, role, is_family_creator, created_at
         from app.members
        where family_id = $1
          and ($2::timestamptz is null or (created_at, id) > ($2, $3::uuid))
        order by created_at asc, id asc
        limit $4`,
      [params.familyId, params.after?.createdAt ?? null, params.after?.id ?? null, params.limit],
    );
    return result.rows.map(toRecord);
  }

  public async findMember(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<MemberRecord | undefined> {
    const result = await asPostgresClient(tx).query<MemberRow>(
      `select id, display_name, role, is_family_creator, created_at
         from app.members where family_id = $1 and id = $2`,
      [params.familyId, params.memberId],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : toRecord(row);
  }

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

  public async insertMember(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly familyId: string;
      readonly name: string;
      readonly role: MemberRole;
      readonly createdAt: Date;
    },
  ): Promise<MemberRecord> {
    const result = await asPostgresClient(tx).query<MemberRow>(
      `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
       values ($1, $2, $3, false, $4, $5, $5)
       returning id, display_name, role, is_family_creator, created_at`,
      [params.id, params.familyId, params.role, params.name, params.createdAt],
    );
    const row = result.rows[0];
    if (row === undefined) {
      throw new TypeError('Member insertion did not return the persisted record.');
    }
    return toRecord(row);
  }
}
