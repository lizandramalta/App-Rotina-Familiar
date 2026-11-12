import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  InviteActorState,
  InviteTarget,
  MemberInviteRepositoryPort,
} from '../application/member-invite-repository-port.js';

/** Consultas parametrizadas, sempre delimitadas pela família da sessão. */
export class PostgresMemberInviteRepository implements MemberInviteRepositoryPort {
  public async findActorState(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly sessionId: string;
    },
  ): Promise<InviteActorState | undefined> {
    const result = await asPostgresClient(tx).query<{ role: string; session_active: boolean }>(
      `select m.role,
              exists (
                select 1 from app.sessions s
                 where s.id = $3 and s.member_id = m.id and s.revoked_at is null
              ) as session_active
         from app.members m
        where m.family_id = $1 and m.id = $2 and m.removed_at is null`,
      [params.familyId, params.memberId, params.sessionId],
    );
    const row = result.rows[0];
    if (row === undefined || !isValidMemberRole(row.role)) {
      return undefined;
    }
    return { role: row.role, sessionActive: row.session_active };
  }

  public async findTarget(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<InviteTarget | undefined> {
    const result = await asPostgresClient(tx).query<{ id: string; is_family_creator: boolean }>(
      `select id, is_family_creator from app.members where family_id = $1 and id = $2 and removed_at is null`,
      [params.familyId, params.memberId],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : { id: row.id, isFamilyCreator: row.is_family_creator };
  }

  public async invalidateAvailableInvites(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly at: Date },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.member_invites
          set status = 'invalidated', invalidated_at = $3
        where family_id = $1 and member_id = $2 and status = 'available'`,
      [params.familyId, params.memberId, params.at],
    );
  }

  public async insertInvite(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly familyId: string;
      readonly memberId: string;
      readonly issuedByMemberId: string;
      readonly tokenHash: string;
      readonly passwordVerifier: string;
      readonly createdAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.member_invites
         (id, family_id, member_id, issued_by_member_id, token_hash, password_verifier, status, created_at)
       values ($1, $2, $3, $4, $5, $6, 'available', $7)`,
      [
        params.id,
        params.familyId,
        params.memberId,
        params.issuedByMemberId,
        params.tokenHash,
        params.passwordVerifier,
        params.createdAt,
      ],
    );
  }
}
