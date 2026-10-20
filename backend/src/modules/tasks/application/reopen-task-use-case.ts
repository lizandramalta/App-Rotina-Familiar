import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import {
  MissionReopenRequiresConfirmationError,
  TaskNotCompletedError,
} from '../domain/task-reopening-errors.js';
import type { TaskRecord, TaskRepositoryPort } from './task-repository-port.js';
import type { MissionReopeningPort, RemovedBadge } from './mission-reopening-port.js';

export interface ReopenTaskResult {
  readonly task: {
    readonly id: string;
    readonly title: string;
    readonly weight: number;
    readonly scheduledDate: string;
    readonly assigneeIds: readonly string[];
    readonly note: string | null;
    readonly status: 'pending';
    readonly routineId: string | null;
    readonly createdAt: string;
  };
  readonly affectedResources: {
    readonly missionsReopened: readonly {
      readonly id: string;
      readonly title: string;
      readonly status: 'inProgress';
    }[];
    readonly participationsRemoved: number;
    readonly badgesRemoved: readonly RemovedBadge[];
    readonly rewardRemoved: boolean;
  };
}

function toResponse(task: TaskRecord): ReopenTaskResult['task'] {
  if (task.status !== 'pending') {
    throw new Error('The reopened task did not return its canonical pending state.');
  }
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

/** SPEC-011 phase 1 / SCRUM-56, CA-01 through CA-08. */
export class ReopenTaskUseCase {
  constructor(
    private readonly deps: {
      readonly tasks: TaskRepositoryPort;
      readonly missions: MissionReopeningPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(
    actor: ActorContext,
    taskId: string,
    confirm: boolean,
    requestId?: string,
  ): Promise<ReopenTaskResult> {
    try {
      const result = await this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const role = await this.deps.tasks.findMemberRole(tx, actor.familyId, actor.memberId);
        if (role === undefined) {
          throw new NotFoundError('Task not found.');
        }
        const task = await this.deps.tasks.findTask(tx, actor.familyId, taskId, true);
        if (task === undefined) {
          throw new NotFoundError('Task not found.');
        }
        if (role === MemberRole.KIDS && !task.assigneeIds.includes(actor.memberId)) {
          throw new ActionNotAllowedError();
        }
        if (task.status !== 'completed') {
          throw new TaskNotCompletedError();
        }

        const linked = await this.deps.missions.findLinkedMissions(tx, actor.familyId, task.id);
        const affected = linked.filter((mission) => mission.completed || mission.hasAcceptedReward);
        const hasAcceptedReward = affected.some((mission) => mission.hasAcceptedReward);
        if (affected.length > 0 && !confirm) {
          throw new MissionReopenRequiresConfirmationError(
            affected.map(({ id, title }) => ({ id, title })),
            hasAcceptedReward,
          );
        }

        const now = this.deps.clock.now();
        const reopened = await this.deps.tasks.reopenTask(tx, {
          task,
          actorId: actor.memberId,
          now,
        });
        const effects = await this.deps.missions.reopenCompletedMissions(tx, {
          familyId: actor.familyId,
          missionIds: affected.map((mission) => mission.id),
          now,
        });
        return {
          task: toResponse(reopened),
          affectedResources: {
            missionsReopened: affected.map(({ id, title }) => ({
              id,
              title,
              status: 'inProgress' as const,
            })),
            ...effects,
          },
        };
      });
      this.deps.logger.info('task_reopened', {
        taskId,
        familyId: actor.familyId,
        actorId: actor.memberId,
        missionsReopenedCount: result.affectedResources.missionsReopened.length,
        hadAcceptedReward: result.affectedResources.rewardRemoved,
      });
      return result;
    } catch (error) {
      if (error instanceof MissionReopenRequiresConfirmationError) {
        this.deps.logger.info('task_reopen_confirmation_required', {
          taskId,
          familyId: actor.familyId,
          requestId,
        });
      } else if (error instanceof DomainError) {
        this.deps.logger.info('task_reopen_denied', {
          requestId,
          actorId: actor.memberId,
          targetFamilyId: actor.familyId,
          code: error.code,
        });
      }
      if (error instanceof DomainError) {
        throw error;
      }
      throw new DependencyUnavailableError();
    }
  }
}
