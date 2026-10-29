import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { FamilySettingsRepositoryPort } from '../../family/application/family-settings-repository-port.js';
import type { MissionClosurePort } from '../../tasks/application/mission-closure-port.js';
import {
  normalizeAssigneeIds,
  validateAssignees,
} from '../../tasks/application/manage-task-use-cases.js';
import type { TaskRepositoryPort } from '../../tasks/application/task-repository-port.js';
import {
  MissionCompletedProtectedError,
  MissionWouldHaveNoTasksError,
} from '../../tasks/domain/task-errors.js';
import {
  validateNote,
  validateTaskTitle,
  validateWeight,
} from '../../tasks/domain/task-validation.js';
import { toRoutineResponse, type RoutineResponse } from './create-routine-use-case.js';
import { materializationHorizon } from '../domain/materialization-horizon.js';
import type { RoutineRepositoryPort } from './routine-repository-port.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function validateSourceTaskId(value: unknown): string {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    throw new ValidationError('Routine source task is invalid.', {
      fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'],
    });
  }
  return value;
}

async function requireCurrentAdult(
  repository: TaskRepositoryPort,
  tx: Parameters<TaskRepositoryPort['findMemberRole']>[0],
  actor: ActorContext,
): Promise<void> {
  const role = await repository.findMemberRole(tx, actor.familyId, actor.memberId);
  if (role === undefined || role === MemberRole.KIDS) {
    throw new ActionNotAllowedError();
  }
}

export interface UpdateFutureRoutineCommand {
  readonly actor: ActorContext;
  readonly routineId: string;
  readonly fromTaskId: unknown;
  readonly title: unknown;
  readonly weight: unknown;
  readonly assigneeIds: unknown;
  readonly note: unknown;
}

export interface UpdateFutureRoutineResult {
  readonly routine: RoutineResponse;
  readonly updatedTaskIds: readonly string[];
  readonly preservedTaskIds: readonly string[];
}

export class UpdateFutureRoutineUseCase {
  constructor(
    private readonly deps: {
      readonly routineRepository: RoutineRepositoryPort;
      readonly taskRepository: TaskRepositoryPort;
      readonly familySettingsRepository: FamilySettingsRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: UpdateFutureRoutineCommand): Promise<UpdateFutureRoutineResult> {
    if (command.actor.role === MemberRole.KIDS) throw new ActionNotAllowedError();
    if (!UUID_PATTERN.test(command.routineId)) throw new NotFoundError('Routine not found.');
    const fromTaskId = validateSourceTaskId(command.fromTaskId);

    const result = await this.deps.transactionRunner.forFamily(
      command.actor.familyId,
      async (tx) => {
        await requireCurrentAdult(this.deps.taskRepository, tx, command.actor);
        const routine = await this.deps.routineRepository.findRoutine(
          tx,
          command.actor.familyId,
          command.routineId,
          true,
        );
        if (routine === undefined) throw new NotFoundError('Routine not found.');

        const source = await this.deps.routineRepository.findSourceOccurrence(
          tx,
          command.actor.familyId,
          fromTaskId,
        );
        if (source === undefined) throw new NotFoundError('Routine source task not found.');
        if (source.routineId !== routine.id) {
          throw new ValidationError('Routine source task does not belong to this routine.', {
            fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'],
          });
        }
        if (source.isProtected) throw new MissionCompletedProtectedError();

        const title =
          command.title === undefined ? routine.title : validateTaskTitle(command.title);
        const weight =
          command.weight === undefined ? routine.weight : validateWeight(command.weight);
        const note = command.note === undefined ? routine.note : validateNote(command.note);
        const assigneeIds =
          command.assigneeIds === undefined
            ? routine.assigneeIds
            : normalizeAssigneeIds(command.assigneeIds);
        await validateAssignees(this.deps.taskRepository, tx, command.actor.familyId, assigneeIds);

        const occurrences = await this.deps.routineRepository.listFutureOccurrences(
          tx,
          command.actor.familyId,
          routine.id,
          source.originalDate,
          routine.taskTemplateId,
        );
        const updatedTaskIds = occurrences
          .filter((occurrence) => occurrence.status !== 'completed' && !occurrence.isProtected)
          .map((occurrence) => occurrence.id);
        const preservedTaskIds = occurrences
          .filter((occurrence) => occurrence.status === 'completed' || occurrence.isProtected)
          .map((occurrence) => occurrence.id);
        const now = this.deps.clock.now();
        await this.deps.routineRepository.updateConfiguration(tx, {
          routine,
          title,
          weight,
          note,
          assigneeIds,
          now,
        });
        await this.deps.routineRepository.updateOccurrences(tx, {
          familyId: command.actor.familyId,
          taskIds: updatedTaskIds,
          title,
          weight,
          note,
          assigneeIds,
          actorId: command.actor.memberId,
          now,
        });

        const timeZoneId = await this.deps.familySettingsRepository.findFamilyTimeZone(
          tx,
          command.actor.familyId,
        );
        if (timeZoneId === undefined) throw new NotFoundError('Family not found.');
        const isComplete =
          !routine.isActive ||
          (routine.generatedUntil !== null &&
            routine.generatedUntil >= materializationHorizon(now, timeZoneId));
        return {
          routine: toRoutineResponse({ ...routine, title, weight, note, assigneeIds }, isComplete),
          updatedTaskIds,
          preservedTaskIds,
        };
      },
    );
    this.deps.logger.info('routine_updated', {
      routineId: command.routineId,
      familyId: command.actor.familyId,
      fromTaskId,
    });
    return result;
  }
}

export interface DeleteFutureRoutineTasksCommand {
  readonly actor: ActorContext;
  readonly routineId: string;
  readonly fromTaskId: unknown;
}

export interface DeleteFutureRoutineTasksResult {
  readonly routineId: string;
  readonly deletedTaskIds: readonly string[];
  readonly preservedTaskIds: readonly string[];
  readonly generationEnded: true;
}

export class DeleteFutureRoutineTasksUseCase {
  constructor(
    private readonly deps: {
      readonly routineRepository: RoutineRepositoryPort;
      readonly taskRepository: TaskRepositoryPort;
      readonly missionCloser: MissionClosurePort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(
    command: DeleteFutureRoutineTasksCommand,
  ): Promise<DeleteFutureRoutineTasksResult> {
    if (command.actor.role === MemberRole.KIDS) throw new ActionNotAllowedError();
    if (!UUID_PATTERN.test(command.routineId)) throw new NotFoundError('Routine not found.');
    const fromTaskId = validateSourceTaskId(command.fromTaskId);

    const result = await this.deps.transactionRunner.forFamily(
      command.actor.familyId,
      async (tx) => {
        await requireCurrentAdult(this.deps.taskRepository, tx, command.actor);
        const routine = await this.deps.routineRepository.findRoutine(
          tx,
          command.actor.familyId,
          command.routineId,
          true,
        );
        if (routine === undefined) throw new NotFoundError('Routine not found.');
        const source = await this.deps.routineRepository.findSourceOccurrence(
          tx,
          command.actor.familyId,
          fromTaskId,
        );
        if (source === undefined) throw new NotFoundError('Routine source task not found.');
        if (source.routineId !== routine.id) {
          throw new ValidationError('Routine source task does not belong to this routine.', {
            fromTaskId: ['ROUTINE_SOURCE_TASK_INVALID'],
          });
        }

        const occurrences = await this.deps.routineRepository.listFutureOccurrences(
          tx,
          command.actor.familyId,
          routine.id,
          source.originalDate,
          routine.taskTemplateId,
        );
        const deletedTaskIds = occurrences
          .filter((occurrence) => occurrence.status !== 'completed' && !occurrence.isProtected)
          .map((occurrence) => occurrence.id);
        const preservedTaskIds = occurrences
          .filter((occurrence) => occurrence.status === 'completed' || occurrence.isProtected)
          .map((occurrence) => occurrence.id);
        if (
          await this.deps.routineRepository.wouldEmptyActiveMission(
            tx,
            command.actor.familyId,
            deletedTaskIds,
          )
        )
          throw new MissionWouldHaveNoTasksError();

        const now = this.deps.clock.now();
        const missionIds = await this.deps.routineRepository.deleteOccurrences(tx, {
          familyId: command.actor.familyId,
          taskIds: deletedTaskIds,
          actorId: command.actor.memberId,
          now,
        });
        await this.deps.missionCloser.closeAfterTaskDeletion(tx, {
          familyId: command.actor.familyId,
          missionIds,
          now,
        });
        await this.deps.routineRepository.endGeneration(
          tx,
          command.actor.familyId,
          routine.id,
          now,
        );
        return {
          routineId: routine.id,
          deletedTaskIds,
          preservedTaskIds,
          generationEnded: true as const,
        };
      },
    );
    this.deps.logger.info('routine_generation_ended', {
      routineId: command.routineId,
      familyId: command.actor.familyId,
      fromTaskId,
      preservedCount: result.preservedTaskIds.length,
    });
    return result;
  }
}
