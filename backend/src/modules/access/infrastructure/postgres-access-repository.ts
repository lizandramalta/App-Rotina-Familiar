import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import type {
  AccessRepositoryPort,
  CreatorIdentityRecord,
  CreatorMembershipRecord,
  InsertAccessTokenParams,
  InsertCreationGrantParams,
  InsertSessionParams,
} from '../application/access-repository-port.js';

interface CreatorIdentityRow {
  id: string;
  apple_subject_hash: string;
}

interface CreatorMembershipRow {
  member_id: string;
  family_id: string;
  role: string;
  is_family_creator: boolean;
}

interface SessionIdRow {
  id: string;
}

/**
 * Adaptador PostgreSQL do módulo Access. Todas as queries são parametrizadas e
 * recebem o client da transação em curso, nunca o pool: a atomicidade de CA-05
 * depende de tudo correr na mesma conexão.
 */
export class PostgresAccessRepository implements AccessRepositoryPort {
  public async findCreatorIdentityByAppleSubjectHash(
    tx: TransactionContext,
    appleSubjectHash: string,
  ): Promise<CreatorIdentityRecord | undefined> {
    const result = await asPostgresClient(tx).query<CreatorIdentityRow>(
      `select id, apple_subject_hash
         from app.creator_identities
        where apple_subject_hash = $1`,
      [appleSubjectHash],
    );

    const row = result.rows[0];
    return row === undefined ? undefined : { id: row.id, appleSubjectHash: row.apple_subject_hash };
  }

  public async insertCreatorIdentity(
    tx: TransactionContext,
    params: {
      readonly identityId: string;
      readonly appleSubjectHash: string;
      readonly appleSubjectEncrypted: string;
    },
  ): Promise<CreatorIdentityRecord> {
    // Duas autenticações simultâneas da mesma identidade nova disputam a
    // inserção; a segunda reaproveita a linha existente em vez de falhar.
    const result = await asPostgresClient(tx).query<CreatorIdentityRow>(
      `insert into app.creator_identities (id, apple_subject_hash, apple_subject_encrypted)
            values ($1, $2, $3)
       on conflict (apple_subject_hash) do update
              set updated_at = now()
        returning id, apple_subject_hash`,
      [params.identityId, params.appleSubjectHash, params.appleSubjectEncrypted],
    );

    const row = result.rows[0];
    if (row === undefined) {
      throw new Error('Failed to persist the Apple creator identity.');
    }

    return { id: row.id, appleSubjectHash: row.apple_subject_hash };
  }

  public async findCreatorMembership(
    tx: TransactionContext,
    creatorIdentityId: string,
  ): Promise<CreatorMembershipRecord | undefined> {
    const result = await asPostgresClient(tx).query<CreatorMembershipRow>(
      `select id as member_id, family_id, role, is_family_creator
         from app.members
        where creator_identity_id = $1`,
      [creatorIdentityId],
    );

    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }

    return {
      memberId: row.member_id,
      familyId: row.family_id,
      // O check da coluna já restringe os valores; validar aqui evita confiar em
      // um `as MemberRole` cego se a tabela mudar.
      role: isValidMemberRole(row.role) ? row.role : MemberRole.ADMINISTRATOR,
      isFamilyCreator: row.is_family_creator,
    };
  }

  public async revokeActiveSessionsForMember(
    tx: TransactionContext,
    params: { readonly memberId: string; readonly reason: string },
  ): Promise<string[]> {
    const result = await asPostgresClient(tx).query<SessionIdRow>(
      `update app.sessions
          set revoked_at = now(),
              revoked_reason = $2
        where member_id = $1
          and revoked_at is null
     returning id`,
      [params.memberId, params.reason],
    );

    return result.rows.map((row) => row.id);
  }

  public async insertSession(tx: TransactionContext, params: InsertSessionParams): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.sessions
              (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
       values ($1, $2, $3, $4, $5)`,
      [
        params.sessionId,
        params.familyId,
        params.memberId,
        params.refreshTokenHash,
        params.installationProofHash,
      ],
    );
  }

  public async insertAccessToken(
    tx: TransactionContext,
    params: InsertAccessTokenParams,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
       values ($1, $2, $3, $4)`,
      [params.accessTokenId, params.sessionId, params.tokenHash, params.expiresAt],
    );
  }

  public async insertCreationGrant(
    tx: TransactionContext,
    params: InsertCreationGrantParams,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.family_creation_grants
              (id, creator_identity_id, grant_token_hash, installation_proof_hash, expires_at)
       values ($1, $2, $3, $4, $5)`,
      [
        params.grantId,
        params.creatorIdentityId,
        params.grantTokenHash,
        params.installationProofHash,
        params.expiresAt,
      ],
    );
  }
}
