import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import {
  MediaPurpose,
  MediaState,
  type MediaContentRecord,
  type MediaRecord,
  type MediaRepositoryPort,
} from '../application/media-ports.js';

interface MediaRow {
  id: string;
  owner_member_id: string;
  purpose: string;
  state: string;
}

interface MediaContentRow {
  object_key: string;
  content_type: string | null;
  state: string;
}

const isPurpose = (value: string): value is MediaPurpose =>
  Object.values(MediaPurpose).includes(value as MediaPurpose);
const isState = (value: string): value is MediaState =>
  Object.values(MediaState).includes(value as MediaState);

export class PostgresMediaRepository implements MediaRepositoryPort {
  public async reserve(
    tx: TransactionContext,
    params: {
      readonly mediaId: string;
      readonly familyId: string;
      readonly ownerMemberId: string;
      readonly objectKey: string;
      readonly purpose: MediaPurpose;
    },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `insert into app.media_assets
              (id, family_id, owner_member_id, object_key, purpose, state)
       values ($1, $2, $3, $4, $5, 'UPLOADING')`,
      [params.mediaId, params.familyId, params.ownerMemberId, params.objectKey, params.purpose],
    );
  }

  public async markReady(
    tx: TransactionContext,
    params: { readonly mediaId: string; readonly sizeBytes: number; readonly contentType: string },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.media_assets
          set state = 'READY', size_bytes = $2, content_type = $3
        where id = $1 and state = 'UPLOADING'`,
      [params.mediaId, params.sizeBytes, params.contentType],
    );
  }

  public async markFailed(tx: TransactionContext, mediaId: string): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.media_assets set state = 'FAILED' where id = $1 and state = 'UPLOADING'`,
      [mediaId],
    );
  }

  public async findInFamily(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly mediaId: string },
  ): Promise<MediaRecord | undefined> {
    const result = await asPostgresClient(tx).query<MediaRow>(
      `select id, owner_member_id, purpose, state
         from app.media_assets
        where family_id = $1 and id = $2`,
      [params.familyId, params.mediaId],
    );

    const row = result.rows[0];
    if (row === undefined || !isPurpose(row.purpose) || !isState(row.state)) {
      return undefined;
    }

    return {
      id: row.id,
      ownerMemberId: row.owner_member_id,
      purpose: row.purpose,
      state: row.state,
    };
  }

  public async findContentInFamily(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly mediaId: string },
  ): Promise<MediaContentRecord | undefined> {
    const result = await asPostgresClient(tx).query<MediaContentRow>(
      `select object_key, content_type, state
         from app.media_assets
        where family_id = $1 and id = $2`,
      [params.familyId, params.mediaId],
    );

    const row = result.rows[0];
    if (row === undefined || !isState(row.state)) {
      return undefined;
    }

    // Todo upload é normalizado para JPEG (ImageProcessorPort), então é o
    // padrão seguro caso o tipo ainda não tenha sido gravado.
    return {
      objectKey: row.object_key,
      contentType: row.content_type ?? 'image/jpeg',
      state: row.state,
    };
  }

  public async markLinked(
    tx: TransactionContext,
    params: { readonly mediaId: string; readonly linkedAt: Date },
  ): Promise<void> {
    await asPostgresClient(tx).query(
      `update app.media_assets set linked_at = coalesce(linked_at, $2) where id = $1`,
      [params.mediaId, params.linkedAt],
    );
  }
}
