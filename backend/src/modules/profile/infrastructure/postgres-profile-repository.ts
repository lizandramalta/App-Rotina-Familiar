import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import { asPostgresClient } from '../../../shared/infrastructure/postgres/postgres-transaction-runner.js';
import type { ProfileRepositoryPort } from '../application/profile-repository-port.js';

export class PostgresProfileRepository implements ProfileRepositoryPort {
  public async setPhoto(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly photoMediaId: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void> {
    // O escopo por família e membro vem da sessão; a FK composta de
    // `photo_media_id` impede ainda uma mídia de outra família no banco.
    await asPostgresClient(tx).query(
      `update app.members
          set photo_media_id = $3, updated_at = $4
        where family_id = $1 and id = $2`,
      [params.familyId, params.memberId, params.photoMediaId, params.updatedAt],
    );
  }
}
