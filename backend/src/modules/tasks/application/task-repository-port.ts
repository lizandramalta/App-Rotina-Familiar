import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

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
  /** Current valid completion, populated by family list queries when requested. */
  readonly completedAt?: Date | null;
  readonly assigneeIds: readonly string[];
}

export interface TaskRepositoryPort {
  /** Cria só o registro de `app.task_templates` (sem ocorrência) — reaproveitado por rotinas. */
  insertTaskTemplate(
    tx: TransactionContext,
    params: {
      readonly taskTemplateId: string;
      readonly familyId: string;
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly now: Date;
    },
  ): Promise<void>;
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
  findMemberRole(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
  ): Promise<MemberRole | undefined>;
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
  hasKidsAssignee(tx: TransactionContext, familyId: string, taskId: string): Promise<boolean>;
  closeCurrentSignalByManualCompletion(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskId: string;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<void>;
  completeTask(
    tx: TransactionContext,
    params: {
      readonly task: TaskRecord;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord>;
  reopenTask(
    tx: TransactionContext,
    params: {
      readonly task: TaskRecord;
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<TaskRecord>;
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
  ): Promise<readonly string[]>;
}
