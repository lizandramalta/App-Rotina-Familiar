import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  InsertJoinRecoveryParams,
  InviteJoinRepositoryPort,
  InviteLookupRecord,
  JoinRecoveryRecord,
  LockedInviteRecord,
} from '../application/invite-join-repository-port.js';

type InviteStatus = InviteLookupRecord['status'];

function toStatus(value: string): InviteStatus {
  return value === 'consumed' || value === 'invalidated' ? value : 'available';
}

/** Consultas parametrizadas; o convite é a única origem de família e perfil. */
export class PostgresInviteJoinRepository implements InviteJoinRepositoryPort {
  public async findInviteByTokenHash(
    tx: TransactionContext,
    tokenHash: string,
  ): Promise<InviteLookupRecord | undefined> {
    const result = await asPostgresClient(tx).query<{
      id: string;
      family_id: string;
      member_id: string;
      status: string;
      password_verifier: string;
    }>(
      `select id, family_id, member_id, status, password_verifier
         from app.member_invites
        where token_hash = $1`,
      [tokenHash],
    );
    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }
    return {
      inviteId: row.id,
      familyId: row.family_id,
      memberId: row.member_id,
      status: toStatus(row.status),
      passwordVerifier: row.password_verifier,
    };
  }

  public async lockInviteForJoin(
    tx: TransactionContext,
    inviteId: string,
  ): Promise<LockedInviteRecord | undefined> {
    // `for update of i`: trava só o convite. O membro entra no join apenas para
    // ler papel e flag do Criador, sempre pela chave composta (família, id).
    const result = await asPostgresClient(tx).query<{
      id: string;
      family_id: string;
      member_id: string;
      status: string;
      role: string;
      is_family_creator: boolean;
    }>(
      `select i.id, i.family_id, i.member_id, i.status, m.role, m.is_family_creator
         from app.member_invites i
         join app.members m on m.family_id = i.family_id and m.id = i.member_id
        where i.id = $1
          for update of i`,
      [inviteId],
    );
    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }
    return {
      inviteId: row.id,
      familyId: row.family_id,
      memberId: row.member_id,
      status: toStatus(row.status),
      role: isValidMemberRole(row.role) ? row.role : MemberRole.KIDS,
      isFamilyCreator: row.is_family_creator,
    };
  }

  public async markInviteConsumed(
    tx: TransactionContext,
    params: { readonly inviteId: string; readonly at: Date },
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `update app.member_invites
          set status = 'consumed', consumed_at = $2
        where id = $1 and status = 'available'`,
      [params.inviteId, params.at],
    );
    return result.rowCount === 1;
  }

  public async insertJoinRecovery(
    tx: TransactionContext,
    params: InsertJoinRecoveryParams,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `insert into app.invite_join_recoveries
              (attempt_id, invite_id, session_id, attempt_secret_hash,
               installation_proof_hash, envelope, created_at, expires_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8)
       on conflict (attempt_id) do nothing`,
      [
        params.attemptId,
        params.inviteId,
        params.sessionId,
        params.attemptSecretHash,
        params.installationProofHash,
        params.envelope,
        params.createdAt,
        params.expiresAt,
      ],
    );
    return result.rowCount === 1;
  }

  public async purgeExpiredJoinRecoveries(tx: TransactionContext, now: Date): Promise<void> {
    await asPostgresClient(tx).query(
      'delete from app.invite_join_recoveries where expires_at <= $1',
      [now],
    );
  }

  public async findJoinRecovery(
    tx: TransactionContext,
    attemptId: string,
  ): Promise<JoinRecoveryRecord | undefined> {
    const result = await asPostgresClient(tx).query<{
      attempt_id: string;
      attempt_secret_hash: string;
      installation_proof_hash: string;
      envelope: string;
      expires_at: Date;
      session_active: boolean;
    }>(
      `select r.attempt_id, r.attempt_secret_hash, r.installation_proof_hash,
              r.envelope, r.expires_at,
              (s.revoked_at is null) as session_active
         from app.invite_join_recoveries r
         join app.sessions s on s.id = r.session_id
        where r.attempt_id = $1`,
      [attemptId],
    );
    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }
    return {
      attemptId: row.attempt_id,
      attemptSecretHash: row.attempt_secret_hash,
      installationProofHash: row.installation_proof_hash,
      envelope: row.envelope,
      expiresAt: row.expires_at,
      sessionActive: row.session_active,
    };
  }

  public async deleteJoinRecovery(tx: TransactionContext, attemptId: string): Promise<void> {
    await asPostgresClient(tx).query(
      'delete from app.invite_join_recoveries where attempt_id = $1',
      [attemptId],
    );
  }
}
