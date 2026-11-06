import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { WeeklyScore } from '../domain/weekly-winners.js';

export interface RecognitionCycle {
  readonly id: string;
  readonly startsAt: Date;
  readonly endsAt: Date;
  readonly timeZoneId: string;
  readonly referenceWeek: string;
  readonly isTransition: boolean;
}

export interface WeeklyRecognitionView {
  readonly id: string;
  readonly period: {
    readonly startsAt: string;
    readonly endsAt: string;
    readonly referenceWeek: string;
  };
  readonly timeZoneId: string;
  readonly isTransition: boolean;
  readonly points: number;
  readonly completedTasks: number;
  readonly isTie: boolean;
  readonly processedAt: string;
  readonly openedAt: string | null;
}

export interface RecognitionRepositoryPort {
  now(tx: TransactionContext): Promise<Date>;
  findUnfinalizedCycles(
    tx: TransactionContext,
    familyId: string,
    now: Date,
  ): Promise<readonly RecognitionCycle[]>;
  scores(
    tx: TransactionContext,
    familyId: string,
    cycle: RecognitionCycle,
  ): Promise<readonly WeeklyScore[]>;
  saveFinalResult(
    tx: TransactionContext,
    familyId: string,
    cycle: RecognitionCycle,
    winners: readonly WeeklyScore[],
    processedAt: Date,
  ): Promise<void>;
  requireActiveSession(tx: TransactionContext, actor: ActorContext): Promise<void>;
  listOwn(tx: TransactionContext, actor: ActorContext): Promise<readonly WeeklyRecognitionView[]>;
  findOwn(
    tx: TransactionContext,
    actor: ActorContext,
    id: string,
  ): Promise<WeeklyRecognitionView | undefined>;
  openOwn(tx: TransactionContext, actor: ActorContext, id: string): Promise<void>;
}

/** Chamada dentro de transação já serializada pela família. */
export interface FinalizeFamilyHighlightsPort {
  finalizeInTransaction(tx: TransactionContext, familyId: string, asOf?: Date): Promise<number>;
}
