import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  ConflictError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { MissionClosurePort } from '../../tasks/application/mission-closure-port.js';
import type {
  TaskRecord,
  TaskRepositoryPort,
} from '../../tasks/application/task-repository-port.js';
import type { KidsSignalRecord, KidsSignalRepositoryPort } from './kids-signal-repository-port.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PAGE_SIZE = 20;

interface Dependencies {
  readonly signals: KidsSignalRepositoryPort;
  readonly tasks: TaskRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly missionCloser: MissionClosurePort;
  readonly clock: Clock;
}

function requireAdmin(actor: ActorContext): void {
  if (actor.role !== MemberRole.ADMINISTRATOR) throw new ActionNotAllowedError();
}

function taskView(task: TaskRecord) {
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

function signalView(signal: KidsSignalRecord) {
  return {
    signalId: signal.id,
    task: { id: signal.taskId, title: signal.taskTitle },
    signaledBy: { id: signal.signaledById, name: signal.childName },
    signaledAt: signal.signaledAt.toISOString(),
    hasPhoto: signal.photoMediaId !== null,
  };
}

async function guarded<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) throw error;
    throw new DependencyUnavailableError();
  }
}

/** SPEC-012 CA-01–06: only a responsible Kids profile may signal a pending task. */
export class SignalTaskUseCase {
  constructor(private readonly deps: Dependencies) {}

  async execute(actor: ActorContext, taskId: string, photoMediaId: unknown) {
    if (actor.role !== MemberRole.KIDS) throw new ActionNotAllowedError();
    if (
      photoMediaId !== undefined &&
      photoMediaId !== null &&
      (typeof photoMediaId !== 'string' || !UUID.test(photoMediaId))
    ) {
      throw new ValidationError('The photo media ID is invalid.', {
        photoMediaId: ['PHOTO_MEDIA_INVALID'],
      });
    }
    return guarded(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const role = await this.deps.tasks.findMemberRole(tx, actor.familyId, actor.memberId);
        if (role !== MemberRole.KIDS) throw new ActionNotAllowedError();
        const task = await this.deps.tasks.findTask(tx, actor.familyId, taskId, true);
        if (!task || !task.assigneeIds.includes(actor.memberId))
          throw new NotFoundError('Task not found.');
        if (task.status !== 'pending')
          throw new ConflictError('Task is no longer pending.', 'TASK_NOT_PENDING');
        if (typeof photoMediaId === 'string') {
          const photo = await this.deps.signals.findPhoto(tx, actor.familyId, photoMediaId);
          if (!photo || photo.ownerMemberId !== actor.memberId) {
            throw new ValidationError(
              'Photo does not belong to the actor.',
              { photoMediaId: ['PHOTO_MEDIA_NOT_OWNED'] },
              'PHOTO_MEDIA_NOT_OWNED',
            );
          }
          if (photo.purpose !== 'TASK_SIGNAL') {
            throw new ValidationError(
              'Photo purpose is invalid.',
              { photoMediaId: ['PHOTO_MEDIA_PURPOSE_MISMATCH'] },
              'PHOTO_MEDIA_PURPOSE_MISMATCH',
            );
          }
          if (photo.state !== 'READY') {
            throw new ValidationError(
              'Photo is not ready.',
              { photoMediaId: ['PHOTO_MEDIA_NOT_READY'] },
              'PHOTO_MEDIA_NOT_READY',
            );
          }
        }
        const now = this.deps.clock.now();
        const signalId = randomUUID();
        await this.deps.signals.createSignal(tx, {
          id: signalId,
          familyId: actor.familyId,
          taskId,
          signaledById: actor.memberId,
          photoMediaId: typeof photoMediaId === 'string' ? photoMediaId : null,
          now,
        });
        await this.deps.signals.setTaskAwaiting(tx, actor.familyId, taskId, now);
        return {
          task: taskView({ ...task, status: 'awaitingConfirmation' as const }),
          signal: {
            id: signalId,
            signaledAt: now.toISOString(),
            hasPhoto: typeof photoMediaId === 'string',
          },
        };
      }),
    );
  }
}

/** SPEC-013 CA-01: stable oldest-first pending queue, scoped to the Admin family. */
export class ListKidsSignalsUseCase {
  constructor(private readonly deps: Dependencies) {}

  async execute(actor: ActorContext, cursor?: string) {
    requireAdmin(actor);
    let after: { signaledAt: Date; signalId: string } | undefined;
    if (cursor) {
      try {
        const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as {
          signaledAt?: string;
          signalId?: string;
        };
        if (!parsed.signaledAt || !parsed.signalId || !UUID.test(parsed.signalId))
          throw new Error();
        const signaledAt = new Date(parsed.signaledAt);
        if (Number.isNaN(signaledAt.getTime())) throw new Error();
        after = { signaledAt, signalId: parsed.signalId };
      } catch {
        throw new ValidationError('The queue cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
      }
    }
    return guarded(async () => {
      const rows = await this.deps.transactionRunner.run((tx) =>
        this.deps.signals.listCurrent(tx, {
          familyId: actor.familyId,
          after,
          limit: PAGE_SIZE + 1,
        }),
      );
      const items = rows.slice(0, PAGE_SIZE);
      const last = items.at(-1);
      return {
        items: items.map(signalView),
        nextCursor:
          rows.length > PAGE_SIZE && last
            ? Buffer.from(
                JSON.stringify({
                  signaledAt: last.signaledAt.toISOString(),
                  signalId: last.id,
                }),
              ).toString('base64url')
            : null,
      };
    });
  }
}

/** SPEC-013 CA-02: detail exists only while the signal is current. */
export class GetKidsSignalUseCase {
  constructor(private readonly deps: Dependencies) {}

  async execute(actor: ActorContext, signalId: string) {
    requireAdmin(actor);
    return guarded(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        if (
          (await this.deps.tasks.findMemberRole(tx, actor.familyId, actor.memberId)) !==
          MemberRole.ADMINISTRATOR
        ) {
          throw new ActionNotAllowedError();
        }
        const signal = await this.deps.signals.findSignal(tx, actor.familyId, signalId);
        if (!signal || signal.discardedAt) throw new NotFoundError('Kids signal not found.');
        const task = await this.deps.tasks.findTask(tx, actor.familyId, signal.taskId);
        if (!task || task.status !== 'awaitingConfirmation')
          throw new NotFoundError('Kids signal not found.');
        return {
          ...signalView(signal),
          task: taskView(task),
          assignees: signal.assignees,
          photoMediaId: signal.photoMediaId,
          capabilities: { canConfirm: true, canReject: true },
        };
      }),
    );
  }
}

/** SPEC-013 CA-03–06: a late command returns canonical state with no repeated effects. */
export class DecideKidsSignalUseCase {
  constructor(private readonly deps: Dependencies) {}

  async execute(actor: ActorContext, signalId: string, decision: unknown) {
    requireAdmin(actor);
    if (decision !== 'confirm' && decision !== 'reject') {
      throw new ValidationError('The decision is invalid.', { decision: ['DECISION_INVALID'] });
    }
    return guarded(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        if (
          (await this.deps.tasks.findMemberRole(tx, actor.familyId, actor.memberId)) !==
          MemberRole.ADMINISTRATOR
        ) {
          throw new ActionNotAllowedError();
        }
        const signal = await this.deps.signals.findSignal(tx, actor.familyId, signalId);
        if (!signal) throw new NotFoundError('Kids signal not found.');
        const task = await this.deps.tasks.findTask(tx, actor.familyId, signal.taskId, true);
        if (!task) throw new NotFoundError('Kids signal not found.');
        if (signal.discardedAt || task.status !== 'awaitingConfirmation') {
          return {
            task: taskView(task),
            decisionOutcome: signal.decision ?? 'closedByManualCompletion',
            applied: false,
          };
        }
        const now = this.deps.clock.now();
        if (decision === 'reject') {
          await this.deps.signals.rejectSignal(tx, {
            signalId,
            familyId: actor.familyId,
            taskId: task.id,
            actorId: actor.memberId,
            now,
          });
          return {
            task: taskView({ ...task, status: 'pending' as const }),
            decisionOutcome: 'rejected',
            applied: true,
          };
        }
        const completed = await this.deps.tasks.completeTask(tx, {
          task,
          actorId: actor.memberId,
          now,
        });
        await this.deps.missionCloser.closeForCompletedTask(tx, {
          familyId: actor.familyId,
          taskId: task.id,
          now,
        });
        await this.deps.signals.resolveSignal(tx, {
          signalId,
          familyId: actor.familyId,
          actorId: actor.memberId,
          outcome: 'confirmed',
          now,
        });
        return { task: taskView(completed), decisionOutcome: 'confirmed', applied: true };
      }),
    );
  }
}
