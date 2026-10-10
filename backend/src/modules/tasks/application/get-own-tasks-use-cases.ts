import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { toLocalDateTime } from '../../family/domain/time-zone.js';
import {
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import type { TaskRecord } from './task-repository-port.js';
import type {
  FamilyCalendarRecord,
  OwnTaskPageCursor,
  TaskQueryRepositoryPort,
} from './task-query-repository-port.js';

export const OWN_TASKS_PAGE_SIZE = 20;

export interface OwnTaskView {
  readonly id: string;
  readonly title: string;
  readonly weight: number;
  readonly scheduledDate: string;
  readonly assigneeIds: readonly string[];
  readonly note: string | null;
  readonly status: TaskRecord['status'];
  readonly routineId: string | null;
  readonly createdAt: string;
}

export interface GetOwnTasksResult {
  readonly items: readonly OwnTaskView[];
  readonly nextCursor: string | null;
}

export interface GetOwnProgressResult {
  readonly total: number;
  readonly completed: number;
  /** `null` evita inventar percentual quando não há tarefas previstas. */
  readonly percentage: number | null;
}

interface OwnTasksCursorPayload {
  readonly referenceDate: string;
  readonly id: string;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function toOwnTaskView(task: TaskRecord): OwnTaskView {
  return {
    id: task.id,
    title: task.title,
    weight: task.weight,
    scheduledDate: task.scheduledDate,
    assigneeIds: task.assigneeIds,
    note: task.note,
    status: task.status,
    routineId: task.routineId,
    createdAt: task.createdAt.toISOString(),
  };
}

function formatLocalDate(date: Date, timeZoneId: string): string {
  const local = toLocalDateTime(date, timeZoneId);
  return `${local.year.toString().padStart(4, '0')}-${local.month
    .toString()
    .padStart(2, '0')}-${local.day.toString().padStart(2, '0')}`;
}

function lastDayOfCurrentLocalMonth(now: Date, timeZoneId: string): string {
  const local = toLocalDateTime(now, timeZoneId);
  const lastDay = new Date(Date.UTC(local.year, local.month, 0)).getUTCDate();
  return `${local.year.toString().padStart(4, '0')}-${local.month
    .toString()
    .padStart(2, '0')}-${lastDay.toString().padStart(2, '0')}`;
}

function validateReferenceDate(input: unknown): string {
  if (typeof input !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    throw new ValidationError('Reference date is invalid.', {
      referenceDate: ['REFERENCE_DATE_INVALID'],
    });
  }

  const [year, month, day] = input.split('-').map(Number);
  const isValid =
    year !== undefined &&
    month !== undefined &&
    day !== undefined &&
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    day <= new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (!isValid) {
    throw new ValidationError('Reference date is invalid.', {
      referenceDate: ['REFERENCE_DATE_INVALID'],
    });
  }
  return input;
}

function ensureReferenceDateInCalendar(
  referenceDate: string,
  calendar: FamilyCalendarRecord,
  now: Date,
): void {
  const firstDate = formatLocalDate(calendar.createdAt, calendar.timeZoneId);
  const lastDate = lastDayOfCurrentLocalMonth(now, calendar.timeZoneId);
  if (referenceDate < firstDate || referenceDate > lastDate) {
    throw new ValidationError('Reference date is outside the available family calendar.', {
      referenceDate: ['REFERENCE_DATE_OUT_OF_RANGE'],
    });
  }
}

function decodeCursor(
  cursor: string | undefined,
  referenceDate: string,
): OwnTaskPageCursor | undefined {
  if (cursor === undefined) {
    return undefined;
  }

  try {
    const parsed: unknown = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      !('referenceDate' in parsed) ||
      !('id' in parsed) ||
      typeof parsed.referenceDate !== 'string' ||
      typeof parsed.id !== 'string' ||
      parsed.referenceDate !== referenceDate ||
      !UUID_PATTERN.test(parsed.id)
    ) {
      throw new Error('invalid cursor');
    }
    return { id: parsed.id };
  } catch {
    throw new ValidationError('The task cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
  }
}

function encodeCursor(referenceDate: string, task: TaskRecord): string {
  const payload: OwnTasksCursorPayload = { referenceDate, id: task.id };
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

async function translateDependencyFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) {
      throw error;
    }
    throw new DependencyUnavailableError();
  }
}

async function resolveReferenceDate(
  repository: TaskQueryRepositoryPort,
  transactionRunner: TransactionRunner,
  clock: Clock,
  actor: ActorContext,
  input: unknown,
): Promise<string> {
  const referenceDate = validateReferenceDate(input);
  const calendar = await translateDependencyFailure(() =>
    transactionRunner.run((tx) => repository.findFamilyCalendar(tx, actor.familyId)),
  );
  if (calendar === undefined) {
    // Uma sessão persistida sem família é inconsistente; não revelar diferenças
    // entre uma família ausente e qualquer outra família.
    throw new NotFoundError('Family calendar not found.');
  }
  ensureReferenceDateInCalendar(referenceDate, calendar, clock.now());
  return referenceDate;
}

export class GetOwnTasksUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskQueryRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(
    actor: ActorContext,
    referenceDateInput: unknown,
    cursorInput: unknown,
  ): Promise<GetOwnTasksResult> {
    const referenceDate = await resolveReferenceDate(
      this.deps.repository,
      this.deps.transactionRunner,
      this.deps.clock,
      actor,
      referenceDateInput,
    );
    const cursor = typeof cursorInput === 'string' || cursorInput === undefined ? cursorInput : '';
    const after = decodeCursor(cursor, referenceDate);
    const records = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findOwnTasksPage(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
          referenceDate,
          after,
          limit: OWN_TASKS_PAGE_SIZE + 1,
        }),
      ),
    );
    const hasNextPage = records.length > OWN_TASKS_PAGE_SIZE;
    const items = records.slice(0, OWN_TASKS_PAGE_SIZE);
    const last = items.at(-1);
    return {
      items: items.map(toOwnTaskView),
      nextCursor: hasNextPage && last !== undefined ? encodeCursor(referenceDate, last) : null,
    };
  }
}

export class GetOwnProgressUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskQueryRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(
    actor: ActorContext,
    referenceDateInput: unknown,
  ): Promise<GetOwnProgressResult> {
    const referenceDate = await resolveReferenceDate(
      this.deps.repository,
      this.deps.transactionRunner,
      this.deps.clock,
      actor,
      referenceDateInput,
    );
    const progress = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.countOwnTasksProgress(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
          referenceDate,
        }),
      ),
    );
    return {
      total: progress.total,
      completed: progress.completed,
      percentage: progress.total === 0 ? null : (progress.completed / progress.total) * 100,
    };
  }
}
