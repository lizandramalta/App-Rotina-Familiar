import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

/**
 * Capacidade de Missions usada por Tasks: reavaliar, na transação corrente, as
 * missões que vinculam a tarefa recém-concluída (SPEC-014 CA-15).
 */
export interface MissionClosurePort {
  closeForCompletedTask(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly taskId: string; readonly now: Date },
  ): Promise<void>;
}
