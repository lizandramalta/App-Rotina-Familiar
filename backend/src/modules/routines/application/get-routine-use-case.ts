import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import { ActionNotAllowedError, NotFoundError } from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { FamilySettingsRepositoryPort } from '../../family/application/family-settings-repository-port.js';
import { materializationHorizon } from '../domain/materialization-horizon.js';
import {
  MAX_OCCURRENCES_PER_MATERIALIZATION_BATCH,
  type RoutineRecord,
  type RoutineRepositoryPort,
} from './routine-repository-port.js';

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

function toRoutineResponse(routine: RoutineRecord, isComplete: boolean): RoutineResponse {
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
 * `GetRoutine` (SPEC-008 Fase 1): consulta a configuração e, se o cursor de
 * materialização (`generated_until`) ainda não alcançou o horizonte atual,
 * completa mais um lote antes de responder (reposição em consulta, RN14).
 */
export class GetRoutineUseCase {
  constructor(
    private readonly deps: {
      readonly routineRepository: RoutineRepositoryPort;
      readonly familySettingsRepository: FamilySettingsRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(actor: ActorContext, routineId: string): Promise<RoutineResponse> {
    if (actor.role === MemberRole.KIDS) {
      throw new ActionNotAllowedError();
    }

    return this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
      // Lock da rotina: serializa contra outra consulta/criação concorrente
      // avançando o mesmo cursor (além do lock de família de `forFamily`).
      const routine = await this.deps.routineRepository.findRoutine(
        tx,
        actor.familyId,
        routineId,
        true,
      );
      if (routine === undefined) {
        throw new NotFoundError('Routine not found.');
      }

      const timeZoneId = await this.deps.familySettingsRepository.findFamilyTimeZone(
        tx,
        actor.familyId,
      );
      if (timeZoneId === undefined) {
        throw new NotFoundError('Family not found.');
      }

      const now = this.deps.clock.now();
      const horizon = materializationHorizon(now, timeZoneId);

      if (routine.generatedUntil !== null && routine.generatedUntil >= horizon) {
        return toRoutineResponse(routine, true);
      }

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
