import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import { NotFoundError, ValidationError } from '../../../shared/domain/domain-error.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  MissionCompletedProtectedError,
  MissionWouldHaveNoTasksError,
  SignalResolutionRequiredError,
  TaskAlreadyCompletedError,
  TaskManagementNotAllowedError,
} from '../domain/task-errors.js';
import {
  validateNote,
  validateScheduledDate,
  validateSignalResolution,
  validateTaskTitle,
  validateWeight,
} from '../domain/task-validation.js';
import type { TaskRecord, TaskRepositoryPort, TaskStatus } from './task-repository-port.js';
import type { MissionClosurePort } from './mission-closure-port.js';

export interface TaskResponse {
  readonly id: string;
  readonly title: string;
  readonly weight: number;
  readonly scheduledDate: string;
  readonly assigneeIds: readonly string[];
  readonly note: string | null;
  readonly status: TaskStatus;
  readonly routineId: string | null;
  readonly createdAt: string;
}

export type AffectedResource =
  | { readonly type: 'task'; readonly id: string }
  | { readonly type: 'ownTasks' | 'ownProgress'; readonly referenceDate: string };

export interface TaskMutationResult {
  readonly task: TaskResponse;
  readonly affectedResources: readonly AffectedResource[];
}

export interface CreateTaskCommand {
  readonly actor: ActorContext;
  readonly title: unknown;
  readonly weight: unknown;
  readonly scheduledDate: unknown;
  readonly assigneeIds: unknown;
  readonly note: unknown;
}

export interface EditTaskCommand {
  readonly actor: ActorContext;
  readonly taskId: string;
  readonly title: unknown;
  readonly weight: unknown;
  readonly scheduledDate: unknown;
  readonly assigneeIds: unknown;
  readonly note: unknown;
  readonly signalResolution: unknown;
}

function requireAdult(actor: ActorContext): void {
  if (actor.role === MemberRole.KIDS) {
    throw new TaskManagementNotAllowedError();
  }
}

function toResponse(task: TaskRecord): TaskResponse {
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

function normalizeAssigneeIds(input: unknown): readonly string[] {
  if (input === undefined || input === null) {
    return [];
  }
  if (!Array.isArray(input) || input.some((id) => typeof id !== 'string')) {
    throw new ValidationError('Assignees are invalid.', {
      assigneeIds: ['ASSIGNEE_NOT_IN_FAMILY'],
    });
  }
  return [...new Set(input)];
}

async function validateAssignees(
  repository: TaskRepositoryPort,
  tx: Parameters<TaskRepositoryPort['countFamilyMembers']>[0],
  familyId: string,
  assigneeIds: readonly string[],
): Promise<void> {
  if (assigneeIds.length === 0) {
    return;
  }
  const found = await repository.countFamilyMembers(tx, familyId, assigneeIds);
  if (found !== assigneeIds.length) {
    throw new ValidationError('Each assignee must belong to the active family.', {
      assigneeIds: ['ASSIGNEE_NOT_IN_FAMILY'],
    });
  }
}

export class CreateTaskUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: CreateTaskCommand): Promise<TaskResponse> {
    requireAdult(command.actor);
    const title = validateTaskTitle(command.title);
    const weight = validateWeight(command.weight);
    const scheduledDate = validateScheduledDate(command.scheduledDate);
    const note = validateNote(command.note);
    const assigneeIds = normalizeAssigneeIds(command.assigneeIds);

    return this.deps.transactionRunner.forFamily(command.actor.familyId, async (tx) => {
      await validateAssignees(this.deps.repository, tx, command.actor.familyId, assigneeIds);
      const task = await this.deps.repository.insertSingleTask(tx, {
        taskTemplateId: randomUUID(),
        taskId: randomUUID(),
        familyId: command.actor.familyId,
        title,
        weight,
        scheduledDate,
        note,
        assigneeIds,
        actorId: command.actor.memberId,
        now: this.deps.clock.now(),
      });
      return toResponse(task);
    });
  }
}

export class GetTaskUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext, taskId: string): Promise<TaskResponse> {
    requireAdult(actor);
    // A leitura é sempre limitada à família da sessão, para não revelar um ID externo.
    const task = await this.deps.transactionRunner.run((tx) =>
      this.deps.repository.findTask(tx, actor.familyId, taskId),
    );
    if (task === undefined) {
      throw new NotFoundError('Task not found.');
    }
    return toResponse(task);
  }
}

export class EditTaskUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: EditTaskCommand): Promise<TaskResponse> {
    requireAdult(command.actor);
    return this.deps.transactionRunner.forFamily(command.actor.familyId, async (tx) => {
      const current = await this.deps.repository.findTask(
        tx,
        command.actor.familyId,
        command.taskId,
        true,
      );
      if (current === undefined) {
        throw new NotFoundError('Task not found.');
      }
      if (await this.deps.repository.hasCompletedMission(tx, current.familyId, current.id)) {
        throw new MissionCompletedProtectedError();
      }

      const hasSignal =
        current.status === 'awaitingConfirmation' &&
        (await this.deps.repository.hasCurrentSignal(tx, current.familyId, current.id));
      const signalResolution =
        current.status === 'awaitingConfirmation'
          ? validateSignalResolution(command.signalResolution)
          : undefined;
      if (current.status === 'awaitingConfirmation' && signalResolution === undefined) {
        throw new SignalResolutionRequiredError();
      }

      const title = command.title === undefined ? current.title : validateTaskTitle(command.title);
      const weight = command.weight === undefined ? current.weight : validateWeight(command.weight);
      const scheduledDate =
        command.scheduledDate === undefined
          ? current.scheduledDate
          : validateScheduledDate(command.scheduledDate);
      const note = command.note === undefined ? current.note : validateNote(command.note);
      const assigneeIds =
        command.assigneeIds === undefined
          ? current.assigneeIds
          : normalizeAssigneeIds(command.assigneeIds);
      await validateAssignees(this.deps.repository, tx, command.actor.familyId, assigneeIds);

      const status: TaskStatus =
        current.status === 'awaitingConfirmation' && signalResolution === 'resetToPending'
          ? 'pending'
          : current.status;
      return toResponse(
        await this.deps.repository.updateTask(tx, {
          task: current,
          title,
          weight,
          scheduledDate,
          note,
          assigneeIds,
          status,
          discardSignal: hasSignal && signalResolution === 'resetToPending',
          actorId: command.actor.memberId,
          now: this.deps.clock.now(),
        }),
      );
    });
  }
}

export class DeleteTaskUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(actor: ActorContext, taskId: string): Promise<{ readonly id: string }> {
    requireAdult(actor);
    return this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
      const task = await this.deps.repository.findTask(tx, actor.familyId, taskId, true);
      if (task === undefined) {
        throw new NotFoundError('Task not found.');
      }
      if (task.status === 'completed') {
        throw new TaskAlreadyCompletedError();
      }
      if (await this.deps.repository.hasCompletedMission(tx, task.familyId, task.id)) {
        throw new MissionCompletedProtectedError();
      }
      if (await this.deps.repository.isOnlyTaskOfAnActiveMission(tx, task.familyId, task.id)) {
        throw new MissionWouldHaveNoTasksError();
      }
      await this.deps.repository.deleteTask(tx, {
        task,
        actorId: actor.memberId,
        now: this.deps.clock.now(),
      });
      return { id: task.id };
    });
  }
}

/** Completa uma ocorrência no lock da família — SPEC-010 Fase 1 / SCRUM-40. */
export class CompleteTaskUseCase {
  constructor(
    private readonly deps: {
      readonly repository: TaskRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly missionCloser: MissionClosurePort;
    },
  ) {}

  public async execute(actor: ActorContext, taskId: string): Promise<TaskMutationResult> {
    return this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
      // O papel é lido novamente depois de adquirir o lock: a sessão autenticou a
      // chamada, mas uma troca de papel concorrente não pode ampliar privilégios.
      const role = await this.deps.repository.findMemberRole(tx, actor.familyId, actor.memberId);
      if (role === undefined) {
        throw new NotFoundError('Task not found.');
      }
      if (role === MemberRole.KIDS) {
        throw new TaskManagementNotAllowedError();
      }

      const task = await this.deps.repository.findTask(tx, actor.familyId, taskId, true);
      if (task === undefined) {
        throw new NotFoundError('Task not found.');
      }
      if (task.status === 'completed') {
        throw new TaskAlreadyCompletedError('Task is already completed.');
      }
      const hasKidsAssignee = await this.deps.repository.hasKidsAssignee(
        tx,
        task.familyId,
        task.id,
      );
      if (hasKidsAssignee && role !== MemberRole.ADMINISTRATOR) {
        throw new TaskManagementNotAllowedError();
      }

      const now = this.deps.clock.now();
      const completed = await this.deps.repository.completeTask(tx, {
        task,
        actorId: actor.memberId,
        now,
      });
      // SPEC-014 CA-15: a missão fecha no mesmo commit da conclusão.
      await this.deps.missionCloser.closeForCompletedTask(tx, {
        familyId: completed.familyId,
        taskId: completed.id,
        now,
      });
      return {
        task: toResponse(completed),
        affectedResources: [
          { type: 'task', id: completed.id },
          { type: 'ownTasks', referenceDate: completed.scheduledDate },
          { type: 'ownProgress', referenceDate: completed.scheduledDate },
        ],
      };
    });
  }
}
