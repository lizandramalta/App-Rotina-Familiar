import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export type TaskStatus = 'pending' | 'awaitingConfirmation' | 'completed';

export interface TaskRecord {
  readonly id: string;
  readonly familyId: string;
  readonly title: string;
  readonly weight: number;
  readonly scheduledDate: string;
  readonly note: string | null;
  readonly status: TaskStatus;
  readonly routineId: string | null;
  readonly createdAt: Date;
  readonly assigneeIds: readonly string[];
}

export interface TaskRepositoryPort {
  insertSingleTask(
    tx: TransactionContext,
    params: {
      readonly taskTemplateId: string;
      readonly taskId: string;
      readonly familyId: string;
      readonly title: string;
      readonly weight: number;
      readonly scheduledDate: string;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord>;
  findTask(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
    forUpdate?: boolean,
  ): Promise<TaskRecord | undefined>;
  countFamilyMembers(
    tx: TransactionContext,
    familyId: string,
    memberIds: readonly string[],
  ): Promise<number>;
  hasCompletedMission(tx: TransactionContext, familyId: string, taskId: string): Promise<boolean>;
  isOnlyTaskOfAnActiveMission(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<boolean>;
  hasCurrentSignal(tx: TransactionContext, familyId: string, taskId: string): Promise<boolean>;
  updateTask(
    tx: TransactionContext,
    params: {
      readonly task: TaskRecord;
      readonly title: string;
      readonly weight: number;
      readonly scheduledDate: string;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly status: TaskStatus;
      readonly discardSignal: boolean;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord>;
  deleteTask(
    tx: TransactionContext,
    params: { readonly task: TaskRecord; readonly actorId: string; readonly now: Date },
  ): Promise<void>;
}
