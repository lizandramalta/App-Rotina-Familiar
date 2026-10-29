import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { ActionNotAllowedError, NotFoundError } from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { FamilySettingsRepositoryPort } from '../../family/application/family-settings-repository-port.js';
import {
  normalizeAssigneeIds,
  validateAssignees,
} from '../../tasks/application/manage-task-use-cases.js';
import type { TaskRepositoryPort } from '../../tasks/application/task-repository-port.js';
import {
  validateNote,
  validateTaskTitle,
  validateWeight,
} from '../../tasks/domain/task-validation.js';
import { materializationHorizon } from '../domain/materialization-horizon.js';
import { validateFrequencyDays, validateStartDate } from '../domain/routine-validation.js';
import {
  MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
  type RoutineRecord,
  type RoutineRepositoryPort,
} from './routine-repository-port.js';

export interface CreateRoutineCommand {
  readonly actor: ActorContext;
  readonly title: unknown;
  readonly weight: unknown;
  readonly assigneeIds: unknown;
  readonly note: unknown;
  readonly startDate: unknown;
  readonly frequencyDays: unknown;
}

export interface RoutineResponse {
  readonly id: string;
  readonly title: string;
  readonly weight: number;
  readonly assigneeIds: readonly string[];
  readonly note: string | null;
  readonly startDate: string;
  readonly frequencyDays: number;
  readonly isActive: boolean;
  readonly materializationState: 'pending' | 'complete';
}

export function toRoutineResponse(routine: RoutineRecord, isComplete: boolean): RoutineResponse {
  return {
    id: routine.id,
    title: routine.title,
    weight: routine.weight,
    assigneeIds: routine.assigneeIds,
    note: routine.note,
    startDate: routine.startDate,
    frequencyDays: routine.frequencyDays,
    isActive: routine.isActive,
    materializationState: isComplete ? 'complete' : 'pending',
  };
}

/**
 * `CreateRoutine` (SPEC-008 Fase 1): cria a configuração de rotina e
 * materializa o primeiro lote de ocorrências — do início até o horizonte (fim
 * do mês seguinte no fuso da família) ou o teto do lote, o que vier primeiro
 * (RN14). Sem job/outbox: tudo roda na mesma transação de família.
 */
export class CreateRoutineUseCase {
  constructor(
    private readonly deps: {
      readonly taskRepository: TaskRepositoryPort;
      readonly routineRepository: RoutineRepositoryPort;
      readonly familySettingsRepository: FamilySettingsRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: CreateRoutineCommand): Promise<RoutineResponse> {
    if (command.actor.role === MemberRole.KIDS) {
      throw new ActionNotAllowedError();
    }

    const title = validateTaskTitle(command.title);
    const weight = validateWeight(command.weight);
    const note = validateNote(command.note);
    const startDate = validateStartDate(command.startDate);
    const frequencyDays = validateFrequencyDays(command.frequencyDays);
    const assigneeIds = normalizeAssigneeIds(command.assigneeIds);

    return this.deps.transactionRunner.forFamily(command.actor.familyId, async (tx) => {
      await validateAssignees(this.deps.taskRepository, tx, command.actor.familyId, assigneeIds);

      const timeZoneId = await this.deps.familySettingsRepository.findFamilyTimeZone(
        tx,
        command.actor.familyId,
      );
      if (timeZoneId === undefined) {
        throw new NotFoundError('Family not found.');
      }

      const now = this.deps.clock.now();
      const taskTemplateId = randomUUID();
      const routineId = randomUUID();

      await this.deps.taskRepository.insertTaskTemplate(tx, {
        taskTemplateId,
        familyId: command.actor.familyId,
        title,
        weight,
        note,
        now,
      });
      await this.deps.routineRepository.insertRoutine(tx, {
        routineId,
        familyId: command.actor.familyId,
        taskTemplateId,
        frequencyDays,
        startDate,
        assigneeIds,
        now,
      });

      const routine: RoutineRecord = {
        id: routineId,
        familyId: command.actor.familyId,
        taskTemplateId,
        title,
        weight,
        note,
        assigneeIds,
        frequencyDays,
        startDate,
        isActive: true,
        generatedUntil: null,
        createdAt: now,
      };

      const horizon = materializationHorizon(now, timeZoneId);
      const result = await this.deps.routineRepository.materializeBatch(tx, {
        routine,
        horizon,
        maxBatch: MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
        now,
      });

      return toRoutineResponse(routine, result.isComplete);
    });
  }
}
