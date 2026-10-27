import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import type {
  AccessRepositoryPort,
  AccessTokenSessionRecord,
  CreatorIdentityRecord,
  CreatorMembershipRecord,
  InsertAccessTokenParams,
  InsertCreationGrantParams,
  InsertSessionParams,
  SessionRecord,
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

interface SessionRow {
  id: string;
  family_id: string;
  member_id: string;
  installation_proof_hash: string;
  revoked_at: Date | null;
}

interface AccessTokenSessionRow {
  session_id: string;
  member_id: string;
  family_id: string;
  role: string;
  is_family_creator: boolean;
  token_expires_at: Date;
  token_revoked_at: Date | null;
  session_revoked_at: Date | null;
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

  public async findSessionByRefreshTokenHash(
    tx: TransactionContext,
    refreshTokenHash: string,
  ): Promise<SessionRecord | undefined> {
    const result = await asPostgresClient(tx).query<SessionRow>(
      `select id, family_id, member_id, installation_proof_hash, revoked_at
         from app.sessions
        where refresh_token_hash = $1`,
      [refreshTokenHash],
    );

    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }

    return {
      sessionId: row.id,
      familyId: row.family_id,
      memberId: row.member_id,
      installationProofHash: row.installation_proof_hash,
      revokedAt: row.revoked_at ?? undefined,
    };
  }

  /**
   * O join com `app.members` usa a chave composta `(family_id, id)`: é a mesma
   * garantia da FK da sessão, então o papel devolvido é sempre o do membro
   * daquela família (RNF06).
   */
  public async findSessionAndMemberByAccessTokenHash(
    tx: TransactionContext,
    tokenHash: string,
  ): Promise<AccessTokenSessionRecord | undefined> {
    const result = await asPostgresClient(tx).query<AccessTokenSessionRow>(
      `select s.id            as session_id,
              m.id            as member_id,
              m.family_id     as family_id,
              m.role          as role,
              m.is_family_creator,
              t.expires_at    as token_expires_at,
              t.revoked_at    as token_revoked_at,
              s.revoked_at    as session_revoked_at
         from app.session_access_tokens t
         join app.sessions s on s.id = t.session_id
         join app.members  m on m.family_id = s.family_id and m.id = s.member_id and m.removed_at is null
        where t.token_hash = $1`,
      [tokenHash],
    );

    const row = result.rows[0];
    if (row === undefined) {
      return undefined;
    }

    return {
      sessionId: row.session_id,
      memberId: row.member_id,
      familyId: row.family_id,
      role: isValidMemberRole(row.role) ? row.role : MemberRole.ADMINISTRATOR,
      isFamilyCreator: row.is_family_creator,
      tokenExpiresAt: row.token_expires_at,
      tokenRevokedAt: row.token_revoked_at ?? undefined,
      sessionRevokedAt: row.session_revoked_at ?? undefined,
    };
  }

  public async touchSessionLastSeen(tx: TransactionContext, sessionId: string): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.sessions
          set last_seen_at = now()
        where id = $1
          and revoked_at is null`,
      [sessionId],
    );
  }

  public async revokeSessionById(
    tx: TransactionContext,
    params: { readonly sessionId: string; readonly reason: string },
  ): Promise<boolean> {
    // `revoked_at is null` no WHERE torna a revogação idempotente: uma segunda
    // chamada não sobrescreve o motivo da primeira nem devolve `true` de novo.
    const result = await asPostgresClient(tx).query<SessionIdRow>(
      `update app.sessions
          set revoked_at = now(),
              revoked_reason = $2
        where id = $1
          and revoked_at is null
     returning id`,
      [params.sessionId, params.reason],
    );

    return result.rows.length > 0;
  }

  public async revokeAccessTokensForSession(
    tx: TransactionContext,
    sessionId: string,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.session_access_tokens
          set revoked_at = now()
        where session_id = $1
          and revoked_at is null`,
      [sessionId],
    );
  }

  public async revokePushDevicesForSession(
    tx: TransactionContext,
    sessionId: string,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.push_devices
          set revoked_at = now(),
              updated_at = now()
        where session_id = $1
          and revoked_at is null`,
      [sessionId],
    );
  }
}
