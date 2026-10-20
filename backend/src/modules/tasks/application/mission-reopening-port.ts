import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface LinkedMission {
  readonly id: string;
  readonly title: string;
  readonly completed: boolean;
  readonly hasAcceptedReward: boolean;
}

export interface RemovedBadge {
  readonly memberId: string;
  readonly tier: 'bronze' | 'silver' | 'gold' | 'diamond';
}

export interface MissionReopeningResult {
  readonly participationsRemoved: number;
  readonly badgesRemoved: readonly RemovedBadge[];
  readonly rewardRemoved: boolean;
}

export interface MissionReopeningPort {
  findLinkedMissions(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<readonly LinkedMission[]>;
  reopenCompletedMissions(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly missionIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<MissionReopeningResult>;
}
