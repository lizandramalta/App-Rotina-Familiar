import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

export type MissionStatus = 'inProgress' | 'completed';

export interface MissionRecord {
  readonly id: string;
  readonly familyId: string;
  readonly title: string;
  readonly note: string | null;
  readonly completedAt: Date | null;
  readonly createdAt: Date;
  readonly taskIds: readonly string[];
}

export interface MissionSummaryRecord {
  readonly id: string;
  readonly title: string;
  readonly completedAt: Date | null;
  readonly createdAt: Date;
  readonly taskCount: number;
  readonly completedTaskCount: number;
}

export interface MissionTaskOptionRecord {
  readonly id: string;
  readonly title: string;
  readonly weight: number;
  readonly scheduledDate: string;
  readonly status: 'pending' | 'awaitingConfirmation' | 'completed';
  readonly assigneeIds: readonly string[];
}

/** Posição estável de paginação: ordem decrescente por `(sortKey, id)`. */
export interface PageCursor {
  readonly sortKey: string;
  readonly id: string;
}

export interface ClosedMission {
  readonly missionId: string;
  readonly participationCount: number;
  readonly badgesAwardedCount: number;
}

export interface MissionRepositoryPort {
  findMemberRole(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
  ): Promise<MemberRole | undefined>;
  countFamilyTasks(
    tx: TransactionContext,
    familyId: string,
    taskIds: readonly string[],
  ): Promise<number>;
  insertMission(
    tx: TransactionContext,
    params: {
      readonly missionId: string;
      readonly familyId: string;
      readonly title: string;
      readonly note: string | null;
      readonly taskIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void>;
  findMission(
    tx: TransactionContext,
    familyId: string,
    missionId: string,
    forUpdate?: boolean,
  ): Promise<MissionRecord | undefined>;
  updateMission(
    tx: TransactionContext,
    params: {
      readonly mission: MissionRecord;
      readonly title: string;
      readonly note: string | null;
      readonly taskIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void>;
  listMissions(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly after?: PageCursor; readonly limit: number },
  ): Promise<readonly MissionSummaryRecord[]>;
  listTaskOptions(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly query?: string;
      readonly after?: PageCursor;
      readonly limit: number;
    },
  ): Promise<readonly MissionTaskOptionRecord[]>;
  /**
   * Fecha, na transação corrente, as missões em andamento entre `missionIds`
   * cujas tarefas vinculadas estão todas concluídas. Missão já concluída é
   * ignorada, o que torna a operação idempotente sob o lock da família.
   */
  closeEligible(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly missionIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<readonly ClosedMission[]>;
  findMissionIdsByTask(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<readonly string[]>;
}
