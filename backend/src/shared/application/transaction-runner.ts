/**
 * Port representing an execution context within an active database transaction.
 */
export interface TransactionContext {
  readonly client: unknown;
}

/**
 * Port for coordinating atomic transactions across multiple repositories.
 *
 * Implemented in infrastructure layer using PostgreSQL connection pooling.
 */
export interface TransactionRunner {
  run<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T>;
  forFamily<T>(familyId: string, work: (tx: TransactionContext) => Promise<T>): Promise<T>;
}
