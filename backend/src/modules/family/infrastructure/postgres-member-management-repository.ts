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
        where family_id = $1 and removed_at is null
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
         from app.members where family_id = $1 and id = $2 and removed_at is null`,
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
      `select role from app.members where family_id = $1 and id = $2 and removed_at is null`,
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

  public async updateMember(
    tx: TransactionContext,
    params: { familyId: string; memberId: string; name?: string; role?: MemberRole; now: Date },
  ): Promise<MemberRecord> {
    const result = await asPostgresClient(tx).query<MemberRow>(
      `update app.members
          set display_name = coalesce($3, display_name),
              role = coalesce($4, role), updated_at = $5
        where family_id = $1 and id = $2 and removed_at is null
        returning id, display_name, role, is_family_creator, created_at`,
      [params.familyId, params.memberId, params.name ?? null, params.role ?? null, params.now],
    );
    const row = result.rows[0];
    if (!row) throw new TypeError('Member update did not return the persisted record.');
    return toRecord(row);
  }

  public async removeMember(
    tx: TransactionContext,
    params: { familyId: string; memberId: string; now: Date },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    await client.query(
      `update app.members set removed_at = $3, updated_at = $3
        where family_id = $1 and id = $2 and removed_at is null`,
      [params.familyId, params.memberId, params.now],
    );
    await client.query(
      `update app.sessions set revoked_at = $3, revoked_reason = 'MEMBER_REMOVED'
        where family_id = $1 and member_id = $2 and revoked_at is null`,
      [params.familyId, params.memberId, params.now],
    );
    await client.query(
      `update app.session_access_tokens set revoked_at = $3
        where session_id in (select id from app.sessions where family_id = $1 and member_id = $2)
          and revoked_at is null`,
      [params.familyId, params.memberId, params.now],
    );
    await client.query(
      `update app.push_devices set revoked_at = $3, updated_at = $3
        where session_id in (select id from app.sessions where family_id = $1 and member_id = $2)
          and revoked_at is null`,
      [params.familyId, params.memberId, params.now],
    );
    await client.query(
      `update app.member_invites set status = 'invalidated', invalidated_at = $3
        where family_id = $1 and member_id = $2 and status = 'available'`,
      [params.familyId, params.memberId, params.now],
    );
    await client.query(
      `delete from app.task_assignees a
        using app.task_occurrences t, app.families f
       where a.family_id = $1 and a.member_id = $2
         and t.family_id = a.family_id and t.id = a.task_id
         and f.id = a.family_id
         and t.scheduled_date > ($3::timestamptz at time zone f.timezone)::date
         and t.status = 'pending' and t.deleted_at is null
         and not exists (select 1 from app.mission_tasks mt where mt.family_id = t.family_id and mt.task_id = t.id)
         and not exists (select 1 from app.kids_signals ks where ks.family_id = t.family_id and ks.task_id = t.id and ks.discarded_at is null)`,
      [params.familyId, params.memberId, params.now],
    );
  }
}
