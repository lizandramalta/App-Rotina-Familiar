import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface WeeklyReportRepositoryPort {
  findRole(tx: TransactionContext, familyId: string, memberId: string): Promise<string | undefined>;
  findFamily(
    tx: TransactionContext,
    familyId: string,
  ): Promise<{ timeZoneId: string; createdAt: Date } | undefined>;
  getSnapshot(
    tx: TransactionContext,
    params: { familyId: string; startDate: string; endDate: string },
  ): Promise<{
    totalTasks: number;
    completedTasks: number;
    isTransition: boolean;
    members: readonly {
      memberId: string | null;
      displayName: string;
      weight: number;
      completedTasks: number;
    }[];
  }>;
}
