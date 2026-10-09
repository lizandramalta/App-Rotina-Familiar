import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { TaskRecord } from './task-repository-port.js';

export interface FamilyCalendarRecord {
  readonly createdAt: Date;
  readonly timeZoneId: string;
}

export interface OwnTaskPageCursor {
  readonly id: string;
}

export interface OwnTaskProgressRecord {
  readonly total: number;
  readonly completed: number;
}

/**
 * Leitura diária do próprio perfil, sem expor consultas ou agregados familiares
 * a uma sessão Kids (SPEC-009, Fase 1).
 */
export interface TaskQueryRepositoryPort {
  findFamilyCalendar(
    tx: TransactionContext,
    familyId: string,
  ): Promise<FamilyCalendarRecord | undefined>;
  findOwnTasksPage(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly referenceDate: string;
      readonly after: OwnTaskPageCursor | undefined;
      readonly limit: number;
    },
  ): Promise<readonly TaskRecord[]>;
  countOwnTasksProgress(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly referenceDate: string;
    },
  ): Promise<OwnTaskProgressRecord>;
}
