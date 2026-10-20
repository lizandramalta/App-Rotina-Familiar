import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

export interface RewardItemRecord {
  readonly id: string;
  readonly title: string;
  readonly details: string | null;
  readonly source: 'predefined' | 'custom';
  readonly createdAt: Date;
}

export interface RewardRepositoryPort {
  findActorRole(
    tx: TransactionContext,
    actor: { readonly familyId: string; readonly memberId: string; readonly sessionId: string },
  ): Promise<MemberRole | undefined>;
  listItems(tx: TransactionContext, familyId: string): Promise<readonly RewardItemRecord[]>;
  insertCustom(
    tx: TransactionContext,
    item: {
      readonly id: string;
      readonly familyId: string;
      readonly createdById: string;
      readonly title: string;
      readonly normalizedTitle: string;
      readonly details: string | null;
      readonly createdAt: Date;
    },
  ): Promise<RewardItemRecord>;
}
