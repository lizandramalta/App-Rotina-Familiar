import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import { toLocalDateTime } from '../../family/domain/time-zone.js';
import type { TaskRecord } from './task-repository-port.js';
import type {
  FamilyCalendarRecord,
  FamilyProgressRecord,
  TaskQueryRepositoryPort,
} from './task-query-repository-port.js';

const PAGE_SIZE = 20;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Status = TaskRecord['status'];
type StatusFilter = Status | undefined;

export interface FamilyProgressView {
  readonly total: number;
  readonly completed: number;
  readonly pending: number;
  readonly awaitingConfirmation: number;
  readonly percentage: number | null;
}

export interface FamilyMemberProgressView extends FamilyProgressView {
  readonly memberId: string;
  readonly name: string;
  readonly role: string;
}

export interface FamilyOverviewView {
  readonly startDate: string;
  readonly endDate: string;
  readonly familyCreatedAt: string;
  readonly progress: FamilyProgressView;
  readonly members: readonly FamilyMemberProgressView[];
}

export interface FamilyTaskView {
  readonly id: string;
  readonly title: string;
  readonly weight: number;
  readonly scheduledDate: string;
  readonly assigneeIds: readonly string[];
  readonly note: string | null;
  readonly status: Status;
  readonly displayStatus: Status;
  readonly routineId: string | null;
  readonly createdAt: string;
  readonly completedAt: string | null;
}

export interface FamilyTasksView {
  readonly startDate: string;
  readonly endDate: string;
  readonly items: readonly FamilyTaskView[];
  readonly nextCursor: string | null;
}

interface Dependencies {
  readonly repository: TaskQueryRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly clock: Clock;
}

function requireAdult(actor: ActorContext): void {
  if (actor.role === MemberRole.KIDS) {
    throw new ActionNotAllowedError();
  }
}

function localDate(date: Date, timeZoneId: string): string {
  const local = toLocalDateTime(date, timeZoneId);
  return [
    local.year.toString().padStart(4, '0'),
    local.month.toString().padStart(2, '0'),
    local.day.toString().padStart(2, '0'),
  ].join('-');
}

function lastDayOfMonth(now: Date, timeZoneId: string): string {
  const local = toLocalDateTime(now, timeZoneId);
  const day = new Date(Date.UTC(local.year, local.month, 0)).getUTCDate();
  return [
    local.year.toString().padStart(4, '0'),
    local.month.toString().padStart(2, '0'),
    day.toString().padStart(2, '0'),
  ].join('-');
}

function validateDate(input: unknown, field: 'startDate' | 'endDate'): string {
  if (typeof input !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    throw new ValidationError('Family date is invalid.', { [field]: ['DATE_INVALID'] });
  }
  const [year, month, day] = input.split('-').map(Number);
  if (
    year === undefined ||
    month === undefined ||
    day === undefined ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > new Date(Date.UTC(year, month, 0)).getUTCDate()
  ) {
    throw new ValidationError('Family date is invalid.', { [field]: ['DATE_INVALID'] });
  }
  return input;
}

function validateMemberId(input: unknown): string | undefined {
  if (input === undefined) return undefined;
  if (typeof input !== 'string' || !UUID_PATTERN.test(input)) {
    throw new ValidationError('Member filter is invalid.', { memberId: ['MEMBER_ID_INVALID'] });
  }
  return input;
}

function validateStatus(input: unknown, actor: ActorContext): StatusFilter {
  if (input === undefined) return undefined;
  if (input !== 'pending' && input !== 'completed' && input !== 'awaitingConfirmation') {
    throw new ValidationError('Status filter is invalid.', { status: ['STATUS_INVALID'] });
  }
  if (input === 'awaitingConfirmation' && actor.role !== MemberRole.ADMINISTRATOR) {
    throw new ActionNotAllowedError();
  }
  return input;
}

async function dependency<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) throw error;
    throw new DependencyUnavailableError();
  }
}

async function resolveRange(
  deps: Dependencies,
  actor: ActorContext,
  startInput: unknown,
  endInput: unknown,
  allowDefault = false,
): Promise<{ startDate: string; endDate: string; familyCreatedAt: string }> {
  requireAdult(actor);
  const calendar: FamilyCalendarRecord | undefined = await dependency(() =>
    deps.transactionRunner.run((tx) => deps.repository.findFamilyCalendar(tx, actor.familyId)),
  );
  if (calendar === undefined) throw new NotFoundError('Family calendar not found.');
  const familyCreatedAt = localDate(calendar.createdAt, calendar.timeZoneId);
  let startDate: string;
  let endDate: string;
  if (allowDefault && startInput === undefined && endInput === undefined) {
    const today = localDate(deps.clock.now(), calendar.timeZoneId);
    const monday = new Date(today + 'T00:00:00.000Z');
    monday.setUTCDate(monday.getUTCDate() - ((monday.getUTCDay() + 6) % 7));
    const sunday = new Date(monday);
    sunday.setUTCDate(sunday.getUTCDate() + 6);
    startDate = monday.toISOString().slice(0, 10);
    endDate = sunday.toISOString().slice(0, 10);
    if (startDate < familyCreatedAt) startDate = familyCreatedAt;
    const lastDate = lastDayOfMonth(deps.clock.now(), calendar.timeZoneId);
    if (endDate > lastDate) endDate = lastDate;
  } else {
    startDate = validateDate(startInput, 'startDate');
    endDate = validateDate(endInput, 'endDate');
  }
  if (startDate > endDate) {
    throw new ValidationError('Family date range is reversed.', {
      endDate: ['END_BEFORE_START'],
    });
  }
  if (
    startDate < familyCreatedAt ||
    endDate > lastDayOfMonth(deps.clock.now(), calendar.timeZoneId)
  ) {
    throw new ValidationError('Family date range is outside the available calendar.', {
      startDate: ['DATE_OUT_OF_RANGE'],
      endDate: ['DATE_OUT_OF_RANGE'],
    });
  }
  return { startDate, endDate, familyCreatedAt };
}

function projectProgress(record: FamilyProgressRecord, actor: ActorContext): FamilyProgressView {
  const awaitingConfirmation =
    actor.role === MemberRole.ADMINISTRATOR ? record.awaitingConfirmation : 0;
  return {
    total: record.total,
    completed: record.completed,
    pending:
      record.pending + (actor.role === MemberRole.ADMINISTRATOR ? 0 : record.awaitingConfirmation),
    awaitingConfirmation,
    percentage: record.total === 0 ? null : (record.completed / record.total) * 100,
  };
}

function statusesFor(filter: StatusFilter, actor: ActorContext): readonly Status[] {
  if (filter === undefined) return [];
  if (filter === 'pending' && actor.role === MemberRole.MEMBER) {
    return ['pending', 'awaitingConfirmation'];
  }
  return [filter];
}

function decodeCursor(
  cursorInput: unknown,
  scope: { startDate: string; endDate: string; memberId: string | undefined; status: StatusFilter },
): string | undefined {
  if (cursorInput === undefined) return undefined;
  if (typeof cursorInput !== 'string') {
    throw new ValidationError('Task cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
  }
  try {
    const value: unknown = JSON.parse(Buffer.from(cursorInput, 'base64url').toString('utf8'));
    if (
      typeof value !== 'object' ||
      value === null ||
      !('id' in value) ||
      !('startDate' in value) ||
      !('endDate' in value) ||
      !('memberId' in value) ||
      !('status' in value) ||
      typeof value.id !== 'string' ||
      !UUID_PATTERN.test(value.id) ||
      value.startDate !== scope.startDate ||
      value.endDate !== scope.endDate ||
      value.memberId !== (scope.memberId ?? null) ||
      value.status !== (scope.status ?? null)
    ) {
      throw new Error('invalid cursor');
    }
    return value.id;
  } catch {
    throw new ValidationError('Task cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
  }
}

function encodeCursor(
  id: string,
  scope: { startDate: string; endDate: string; memberId: string | undefined; status: StatusFilter },
): string {
  return Buffer.from(
    JSON.stringify({
      id,
      startDate: scope.startDate,
      endDate: scope.endDate,
      memberId: scope.memberId ?? null,
      status: scope.status ?? null,
    }),
    'utf8',
  ).toString('base64url');
}

export class GetFamilyOverviewUseCase {
  constructor(private readonly deps: Dependencies) {}

  public async execute(
    actor: ActorContext,
    startInput: unknown,
    endInput: unknown,
  ): Promise<FamilyOverviewView> {
    const range = await resolveRange(this.deps, actor, startInput, endInput, true);
    const record = await dependency(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findFamilyOverview(tx, {
          familyId: actor.familyId,
          startDate: range.startDate,
          endDate: range.endDate,
        }),
      ),
    );
    return {
      ...range,
      progress: projectProgress(record.family, actor),
      members: record.members.map((member) => ({
        memberId: member.memberId,
        name: member.name,
        role: member.role,
        ...projectProgress(member, actor),
      })),
    };
  }
}

export class GetFamilyTasksUseCase {
  constructor(private readonly deps: Dependencies) {}

  public async execute(
    actor: ActorContext,
    input: {
      readonly startDate?: unknown;
      readonly endDate?: unknown;
      readonly memberId?: unknown;
      readonly status?: unknown;
      readonly cursor?: unknown;
    },
  ): Promise<FamilyTasksView> {
    const resolved = await resolveRange(this.deps, actor, input.startDate, input.endDate);
    const range = { startDate: resolved.startDate, endDate: resolved.endDate };
    const memberId = validateMemberId(input.memberId);
    const status = validateStatus(input.status, actor);
    const scope = { ...range, memberId, status };
    const afterId = decodeCursor(input.cursor, scope);
    const records = await dependency(() =>
      this.deps.transactionRunner.run(async (tx) => {
        if (
          memberId !== undefined &&
          !(await this.deps.repository.familyMemberExists(tx, {
            familyId: actor.familyId,
            memberId,
          }))
        ) {
          throw new NotFoundError('Member not found.');
        }
        return this.deps.repository.findFamilyTasksPage(tx, {
          familyId: actor.familyId,
          ...range,
          memberId,
          statuses: statusesFor(status, actor),
          afterId,
          limit: PAGE_SIZE + 1,
        });
      }),
    );
    const page = records.slice(0, PAGE_SIZE);
    const last = page.at(-1);
    return {
      ...range,
      items: page.map((task) => ({
        id: task.id,
        title: task.title,
        weight: task.weight,
        scheduledDate: task.scheduledDate,
        assigneeIds: task.assigneeIds,
        note: task.note,
        status: task.status,
        displayStatus:
          actor.role === MemberRole.MEMBER && task.status === 'awaitingConfirmation'
            ? 'pending'
            : task.status,
        routineId: task.routineId,
        createdAt: task.createdAt.toISOString(),
        completedAt: task.status === 'completed' ? task.completedAt?.toISOString() ?? null : null,
      })),
      nextCursor:
        records.length > PAGE_SIZE && last !== undefined ? encodeCursor(last.id, scope) : null,
    };
  }
}
