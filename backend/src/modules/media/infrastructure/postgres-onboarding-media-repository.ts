import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type {
  OnboardingMediaPort,
  OnboardingMediaRecord,
} from '../application/onboarding-media-port.js';

interface MediaRow {
  id: string;
  grant_id: string;
  purpose: string;
  state: string;
  object_key: string;
  size_bytes: string | null;
  content_type: string | null;
}

function record(row: MediaRow): OnboardingMediaRecord {
  return {
    id: row.id,
    grantId: row.grant_id,
    purpose: row.purpose,
    state: row.state,
    objectKey: row.object_key,
    sizeBytes: row.size_bytes === null ? null : Number(row.size_bytes),
    contentType: row.content_type,
  };
}

export class PostgresOnboardingMediaRepository implements OnboardingMediaPort {
  public async findUsableGrant(
    tx: TransactionContext,
    tokenHash: string,
    installationProofHash: string,
    now: Date,
  ): Promise<string | undefined> {
    const result = await asPostgresClient(tx).query<{ id: string }>(
      `select g.id from app.family_creation_grants g
       where g.grant_token_hash = $1 and g.installation_proof_hash = $2
         and g.expires_at > $3 and g.consumed_at is null and g.revoked_at is null
         and not exists (select 1 from app.members m where m.creator_identity_id = g.creator_identity_id)
       for update of g`,
      [tokenHash, installationProofHash, now],
    );
    return result.rows[0]?.id;
  }

  public async reserve(
    tx: TransactionContext,
    input: { id: string; grantId: string; objectKey: string },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.onboarding_media (id, grant_id, object_key, purpose, state)
       values ($1, $2, $3, 'PROFILE_PHOTO', 'UPLOADING')`,
      [input.id, input.grantId, input.objectKey],
    );
  }

  public async markReady(
    tx: TransactionContext,
    input: { id: string; sizeBytes: number; contentType: string },
  ): Promise<void> {
    const result = await asPostgresClient(tx).query(
      `update app.onboarding_media set state = 'READY', size_bytes = $2, content_type = $3
       where id = $1 and state = 'UPLOADING'`,
      [input.id, input.sizeBytes, input.contentType],
    );
    if (result.rowCount !== 1) throw new Error('Onboarding media could not become ready.');
  }

  public async markFailed(tx: TransactionContext, id: string): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.onboarding_media set state = 'FAILED' where id = $1 and state = 'UPLOADING'`,
      [id],
    );
  }

  public async findForGrant(
    tx: TransactionContext,
    id: string,
    grantId: string,
  ): Promise<OnboardingMediaRecord | undefined> {
    const result = await asPostgresClient(tx).query<MediaRow>(
      `select id, grant_id, purpose, state, object_key, size_bytes, content_type
       from app.onboarding_media where id = $1 and grant_id = $2 for update`,
      [id, grantId],
    );
    return result.rows[0] === undefined ? undefined : record(result.rows[0]);
  }

  public async findById(
    tx: TransactionContext,
    id: string,
  ): Promise<OnboardingMediaRecord | undefined> {
    const result = await asPostgresClient(tx).query<MediaRow>(
      `select id, grant_id, purpose, state, object_key, size_bytes, content_type
       from app.onboarding_media where id = $1`,
      [id],
    );
    return result.rows[0] === undefined ? undefined : record(result.rows[0]);
  }

  public async transferToCreator(
    tx: TransactionContext,
    input: { media: OnboardingMediaRecord; familyId: string; memberId: string; now: Date },
  ): Promise<void> {
    const db = asPostgresClient(tx);
    await db.query(
      `insert into app.media_assets
       (id, family_id, owner_member_id, object_key, purpose, state, size_bytes, content_type, linked_at)
       values ($1, $2, $3, $4, 'PROFILE_PHOTO', 'READY', $5, $6, $7)`,
      [
        input.media.id,
        input.familyId,
        input.memberId,
        input.media.objectKey,
        input.media.sizeBytes,
        input.media.contentType,
        input.now,
      ],
    );
    await db.query(`update app.members set photo_media_id = $2 where id = $1 and family_id = $3`, [
      input.memberId,
      input.media.id,
      input.familyId,
    ]);
    const removed = await db.query(`delete from app.onboarding_media where id = $1`, [
      input.media.id,
    ]);
    if (removed.rowCount !== 1) throw new Error('Onboarding media transfer was not completed.');
  }

  public async claimExpired(
    tx: TransactionContext,
    before: Date,
    limit: number,
  ): Promise<readonly OnboardingMediaRecord[]> {
    const result = await asPostgresClient(tx).query<MediaRow>(
      `with candidates as (
         select id from app.onboarding_media
         where created_at < $1 and state in ('UPLOADING', 'READY', 'FAILED', 'DELETING')
         order by created_at, id limit $2 for update skip locked
       )
       update app.onboarding_media m set state = 'DELETING'
       from candidates c where m.id = c.id
       returning m.id, m.grant_id, m.purpose, m.state, m.object_key, m.size_bytes, m.content_type`,
      [before, limit],
    );
    return result.rows.map(record);
  }

  public async deleteClaimed(tx: TransactionContext, id: string): Promise<void> {
    await asPostgresClient(tx).query(
      `delete from app.onboarding_media where id = $1 and state = 'DELETING'`,
      [id],
    );
  }
}
