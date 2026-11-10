import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface EligibleRewardItem {
  readonly id: string;
  readonly title: string;
  readonly details: string | null;
  readonly source: 'predefined' | 'custom';
}

/**
 * Porta definida pelo consumidor (Missions), implementada por Rewards —
 * mesmo padrão de `MissionReopeningPort` (definida em Tasks, implementada por
 * Missions). Evita uma porta pública genérica no módulo Rewards.
 */
export interface RewardCatalogPort {
  /** Elegível: predefinido, ou personalizado da própria família (SPEC-017). */
  findEligibleItem(
    tx: TransactionContext,
    familyId: string,
    rewardItemId: string,
  ): Promise<EligibleRewardItem | undefined>;
}
