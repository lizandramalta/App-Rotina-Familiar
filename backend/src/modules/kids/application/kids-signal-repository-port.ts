import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface KidsSignalRecord {
  readonly id: string;
  readonly familyId: string;
  readonly taskId: string;
  readonly taskTitle: string;
  readonly signaledById: string;
  readonly childName: string;
  readonly signaledAt: Date;
  readonly photoMediaId: string | null;
  readonly discardedAt: Date | null;
  readonly decision: 'confirmed' | 'rejected' | 'closedByManualCompletion' | null;
  readonly assignees: readonly { id: string; name: string }[];
}

export interface KidsSignalRepositoryPort {
  findPhoto(
    tx: TransactionContext,
    familyId: string,
    mediaId: string,
  ): Promise<{ ownerMemberId: string; purpose: string; state: string } | undefined>;
  findSignal(
    tx: TransactionContext,
    familyId: string,
    signalId: string,
  ): Promise<KidsSignalRecord | undefined>;
  listCurrent(
    tx: TransactionContext,
    params: {
      familyId: string;
      after?: { signaledAt: Date; signalId: string };
      limit: number;
    },
  ): Promise<readonly KidsSignalRecord[]>;
  createSignal(
    tx: TransactionContext,
    params: {
      id: string;
      familyId: string;
      taskId: string;
      signaledById: string;
      photoMediaId: string | null;
      now: Date;
    },
  ): Promise<void>;
  setTaskAwaiting(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
    now: Date,
  ): Promise<void>;
  rejectSignal(
    tx: TransactionContext,
    params: {
      signalId: string;
      familyId: string;
      taskId: string;
      actorId: string;
      now: Date;
    },
  ): Promise<void>;
  resolveSignal(
    tx: TransactionContext,
    params: {
      signalId: string;
      familyId: string;
      actorId: string;
      outcome: 'confirmed' | 'closedByManualCompletion';
      now: Date;
    },
  ): Promise<void>;
}
