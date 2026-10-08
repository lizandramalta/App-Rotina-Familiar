import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  CreationGrantRecord,
  FamilyCreationRepositoryPort,
} from '../application/family-creation-repository-port.js';

interface GrantRow {
  id: string;
  creator_identity_id: string;
  installation_proof_hash: string;
}

/**
 * Adaptador PostgreSQL da criação de família. Queries parametrizadas sobre o
 * client da transação em curso, nunca o pool.
 */
export class PostgresFamilyCreationRepository implements FamilyCreationRepositoryPort {
  public async findCreationGrantByTokenHash(
    tx: TransactionContext,
    grantTokenHash: string,
  ): Promise<CreationGrantRecord | undefined> {
    const result = await asPostgresClient(tx).query<GrantRow>(
      `select id, creator_identity_id, installation_proof_hash
         from app.family_creation_grants
        where grant_token_hash = $1`,
      [grantTokenHash],
    );

    const row = result.rows[0];
    return row === undefined
      ? undefined
      : {
          id: row.id,
          creatorIdentityId: row.creator_identity_id,
          installationProofHash: row.installation_proof_hash,
        };
  }

  public async lockCreatorIdentity(
    tx: TransactionContext,
    creatorIdentityId: string,
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `select id from app.creator_identities where id = $1 for update`,
      [creatorIdentityId],
    );
  }

  public async hasFamilyMembership(
    tx: TransactionContext,
    creatorIdentityId: string,
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `select 1 from app.members where creator_identity_id = $1`,
      [creatorIdentityId],
    );

    return result.rowCount !== null && result.rowCount > 0;
  }

  public async consumeCreationGrant(
    tx: TransactionContext,
    params: { readonly grantId: string; readonly now: Date },
  ): Promise<boolean> {
    const result = await asPostgresClient(tx).query(
      `update app.family_creation_grants
          set consumed_at = $2
        where id = $1
          and consumed_at is null
          and revoked_at is null
          and expires_at > $2`,
      [params.grantId, params.now],
    );

    return result.rowCount === 1;
  }

  public async revokeOpenCreationGrants(
    tx: TransactionContext,
    params: { readonly creatorIdentityId: string; readonly now: Date },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.family_creation_grants
          set revoked_at = $2
        where creator_identity_id = $1
          and consumed_at is null
          and revoked_at is null`,
      [params.creatorIdentityId, params.now],
    );
  }

  public async insertFamily(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly name: string;
      readonly timeZoneId: string;
      readonly createdAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.families (id, name, timezone, created_at, updated_at)
       values ($1, $2, $3, $4, $4)`,
      [params.familyId, params.name, params.timeZoneId, params.createdAt],
    );
  }

  public async insertCreatorMember(
    tx: TransactionContext,
    params: {
      readonly memberId: string;
      readonly familyId: string;
      readonly creatorIdentityId: string;
      readonly name: string;
      readonly nickname: string | null;
      readonly createdAt: Date;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.members
              (id, family_id, creator_identity_id, role, is_family_creator,
               display_name, nickname, created_at, updated_at)
       values ($1, $2, $3, 'administrator', true, $4, $5, $6, $6)`,
      [
        params.memberId,
        params.familyId,
        params.creatorIdentityId,
        params.name,
        params.nickname,
        params.createdAt,
      ],
    );
  }

  public async insertWeeklyCycle(
    tx: TransactionContext,
    params: {
      readonly cycleId: string;
      readonly familyId: string;
      readonly startsAt: Date;
      readonly endsAt: Date;
      readonly timeZoneId: string;
      readonly referenceWeek: string;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.weekly_cycles
              (id, family_id, starts_at, ends_at, time_zone, reference_week)
       values ($1, $2, $3, $4, $5, $6)`,
      [
        params.cycleId,
        params.familyId,
        params.startsAt,
        params.endsAt,
        params.timeZoneId,
        params.referenceWeek,
      ],
    );
  }
}
