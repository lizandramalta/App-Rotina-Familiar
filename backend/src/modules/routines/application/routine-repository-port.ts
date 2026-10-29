import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

/**
 * Teto de ocorrências inseridas por chamada de `CreateRoutine`/`GetRoutine`
 * (sem job/outbox nesta entrega — materialização síncrona em lotes limitados).
 */
export const MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH = 2000;

export interface RoutineRecord {
  readonly id: string;
  readonly familyId: string;
  readonly taskTemplateId: string;
  readonly title: string;
  readonly weight: number;
  readonly note: string | null;
  readonly assigneeIds: readonly string[];
  readonly frequencyDays: number;
  readonly startDate: string;
  readonly isActive: boolean;
  /** Última data civil já materializada; `null` antes do primeiro lote. */
  readonly generatedUntil: string | null;
  readonly createdAt: Date;
}

export interface MaterializeBatchResult {
  /** Nova posição do cursor após este lote (sempre avança, nunca retrocede). */
  readonly generatedUntil: string;
  /** `true` quando `generatedUntil` alcançou o horizonte pedido nesta chamada. */
  readonly isComplete: boolean;
}

export interface RoutineOccurrenceRecord {
  readonly id: string;
  readonly routineId: string | null;
  readonly originalDate: string;
  readonly scheduledDate: string;
  readonly status: 'pending' | 'awaitingConfirmation' | 'completed';
  readonly isProtected: boolean;
}

export interface RoutineRepositoryPort {
  findSourceOccurrence(
    tx: TransactionContext,
    familyId: string,
    taskId: string,
  ): Promise<RoutineOccurrenceRecord | undefined>;
  listFutureOccurrences(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    fromOriginalDate: string,
    taskTemplateId: string,
  ): Promise<readonly RoutineOccurrenceRecord[]>;
  updateConfiguration(
    tx: TransactionContext,
    params: {
      readonly routine: RoutineRecord;
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void>;
  updateOccurrences(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskIds: readonly string[];
      readonly title: string;
      readonly weight: number;
      readonly note: string | null;
      readonly assigneeIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<void>;
  wouldEmptyActiveMission(
    tx: TransactionContext,
    familyId: string,
    taskIds: readonly string[],
  ): Promise<boolean>;
  deleteOccurrences(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly taskIds: readonly string[];
      readonly actorId: string;
      readonly now: Date;
    },
  ): Promise<readonly string[]>;
  endGeneration(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    now: Date,
  ): Promise<void>;
  insertRoutine(
    tx: TransactionContext,
    params: {
      readonly routineId: string;
      readonly familyId: string;
      readonly taskTemplateId: string;
      readonly frequencyDays: number;
      readonly startDate: string;
      readonly assigneeIds: readonly string[];
      readonly now: Date;
    },
  ): Promise<void>;

  /** Sempre no escopo da família: rotina de outra família não é encontrada. */
  findRoutine(
    tx: TransactionContext,
    familyId: string,
    routineId: string,
    forUpdate?: boolean,
  ): Promise<RoutineRecord | undefined>;

  /**
   * Insere até `maxBatch` ocorrências entre o cursor atual e `horizon` (grava
   * o novo `generated_until` na mesma chamada) e vincula os responsáveis da
   * rotina a cada ocorrência nova. Idempotente via `ON CONFLICT` em
   * `(task_template_id, origin_key)` — uma retentativa não duplica linhas.
   */
  materializeBatch(
    tx: TransactionContext,
    params: {
      readonly routine: RoutineRecord;
      readonly horizon: string;
      readonly maxBatch: number;
      readonly now: Date;
    },
  ): Promise<MaterializeBatchResult>;
}
