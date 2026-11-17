import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { AppleTokenTypeHint } from '../../../integrations/apple/apple-token-revocation-port.js';
import type {
  AppleTokenRevocationQueuePort,
  ClaimedAppleTokenRevocation,
  ClaimedMediaObjectDeletion,
  MediaObjectDeletionQueuePort,
  OrphanAppleTokenCleanupPort,
} from '../application/account-deletion-ports.js';

interface RevocationRow {
  readonly id: string;
  readonly token_encrypted: string;
  readonly token_type_hint: AppleTokenTypeHint;
  readonly attempts: number;
}

interface MediaDeletionRow {
  readonly id: string;
  readonly object_key: string;
  readonly attempts: number;
}

const toRevocation = (row: RevocationRow): ClaimedAppleTokenRevocation => ({
  id: row.id,
  tokenEncrypted: row.token_encrypted,
  tokenTypeHint: row.token_type_hint,
  attempts: row.attempts,
});

/**
 * Filas pós-commit da exclusão de conta (BA-40). O claim usa `for update skip
 * locked` e lease: um item só é atualizado por quem detém o claim vigente, e um
 * claim expirado pode ser retomado por outro ciclo.
 */
export class PostgresAppleTokenRevocationQueue implements AppleTokenRevocationQueuePort {
  public async claimDue(
    tx: TransactionContext,
    params: {
      readonly now: Date;
      readonly claimId: string;
      readonly leaseUntil: Date;
      readonly limit: number;
    },
  ): Promise<ClaimedAppleTokenRevocation[]> {
    const result = await asPostgresClient(tx).query<RevocationRow>(
      `update app.apple_token_revocations r
          set claim_id = $2, claimed_until = $3
        where r.id in (
          select id from app.apple_token_revocations
           where next_attempt_at <= $1 and (claimed_until is null or claimed_until < $1)
           order by next_attempt_at
           limit $4
           for update skip locked)
        returning r.id, r.token_encrypted, r.token_type_hint, r.attempts`,
      [params.now, params.claimId, params.leaseUntil, params.limit],
    );
    return result.rows.map(toRevocation);
  }

  public async claimById(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly now: Date;
      readonly claimId: string;
      readonly leaseUntil: Date;
    },
  ): Promise<ClaimedAppleTokenRevocation | undefined> {
    const result = await asPostgresClient(tx).query<RevocationRow>(
      `update app.apple_token_revocations
          set claim_id = $2, claimed_until = $3
        where id = $1 and (claimed_until is null or claimed_until < $4)
        returning id, token_encrypted, token_type_hint, attempts`,
      [params.id, params.claimId, params.leaseUntil, params.now],
    );
    const row = result.rows[0];
    return row === undefined ? undefined : toRevocation(row);
  }

  public async complete(
    tx: TransactionContext,
    params: { readonly id: string; readonly claimId: string },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `delete from app.apple_token_revocations where id = $1 and claim_id = $2`,
      [params.id, params.claimId],
    );
  }

  public async reschedule(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly claimId: string;
      readonly attempts: number;
      readonly nextAttemptAt: Date;
      readonly lastError: string;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.apple_token_revocations
          set attempts = $3, next_attempt_at = $4, last_error = $5, claim_id = null, claimed_until = null
        where id = $1 and claim_id = $2`,
      [params.id, params.claimId, params.attempts, params.nextAttemptAt, params.lastError],
    );
  }
}

export class PostgresMediaObjectDeletionQueue implements MediaObjectDeletionQueuePort {
  public async claimDue(
    tx: TransactionContext,
    params: {
      readonly now: Date;
      readonly claimId: string;
      readonly leaseUntil: Date;
      readonly limit: number;
    },
  ): Promise<ClaimedMediaObjectDeletion[]> {
    const result = await asPostgresClient(tx).query<MediaDeletionRow>(
      `update app.media_object_deletions d
          set claim_id = $2, claimed_until = $3
        where d.id in (
          select id from app.media_object_deletions
           where next_attempt_at <= $1 and (claimed_until is null or claimed_until < $1)
           order by next_attempt_at
           limit $4
           for update skip locked)
        returning d.id, d.object_key, d.attempts`,
      [params.now, params.claimId, params.leaseUntil, params.limit],
    );
    return result.rows.map((row) => ({
      id: row.id,
      objectKey: row.object_key,
      attempts: row.attempts,
    }));
  }

  public async complete(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly claimId: string;
      readonly objectKey: string;
      readonly outcome: 'DELETED' | 'FAILED';
    },
  ): Promise<void> {
    const client = asPostgresClient(tx);
    const deleted = await client.query(
      `delete from app.media_object_deletions where id = $1 and claim_id = $2`,
      [params.id, params.claimId],
    );
    if ((deleted.rowCount ?? 0) > 0) {
      await client.query(`update app.media_assets set state = $2 where object_key = $1`, [
        params.objectKey,
        params.outcome,
      ]);
    }
  }

  public async reschedule(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly claimId: string;
      readonly attempts: number;
      readonly nextAttemptAt: Date;
      readonly lastError: string;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.media_object_deletions
          set attempts = $3, next_attempt_at = $4, last_error = $5, claim_id = null, claimed_until = null
        where id = $1 and claim_id = $2`,
      [params.id, params.claimId, params.attempts, params.nextAttemptAt, params.lastError],
    );
  }
}

/** SPEC-001 CA-13 / E-12: identidade sem família após todos os grants expirarem. */
export class PostgresOrphanAppleTokenCleanup implements OrphanAppleTokenCleanupPort {
  public async clearTokensOfIdentitiesWithoutFamily(
    tx: TransactionContext,
    params: { readonly now: Date },
  ): Promise<number> {
    const result = await asPostgresClient(tx).query(
      `update app.creator_identities ci
          set apple_refresh_token_encrypted = null, updated_at = $1
        where ci.apple_refresh_token_encrypted is not null
          and not exists (select 1 from app.members m where m.creator_identity_id = ci.id)
          and not exists (
            select 1 from app.family_creation_grants g
             where g.creator_identity_id = ci.id and g.expires_at > $1)`,
      [params.now],
    );
    return result.rowCount ?? 0;
  }
}
