import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface ProfileRepositoryPort {
  /** Define (ou, com `null`, remove) a foto do próprio membro. */
  setPhoto(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly photoMediaId: string | null;
      readonly updatedAt: Date;
    },
  ): Promise<void>;
}
