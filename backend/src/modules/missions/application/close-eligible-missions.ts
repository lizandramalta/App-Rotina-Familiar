import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MissionRepositoryPort } from './mission-repository-port.js';

export type MissionCloseTrigger = 'create' | 'edit' | 'completeTask';

/**
 * Serviço de aplicação `CloseEligibleMissions` (SPEC-014, UC05): chamado por
 * Missions ao salvar e por Tasks ao concluir, sempre dentro da transação que já
 * detém o lock da família (BA-08). Nunca reabre missão (SPEC-011).
 */
export class CloseEligibleMissions {
  constructor(
    private readonly deps: { readonly repository: MissionRepositoryPort; readonly logger: Logger },
  ) {}

  public async closeByIds(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly missionIds: readonly string[];
      readonly now: Date;
      readonly trigger: MissionCloseTrigger;
    },
  ): Promise<number> {
    if (params.missionIds.length === 0) {
      return 0;
    }
    // Ordem estável por id: fechamentos simultâneos concedem marcos de forma
    // determinística, independentemente da ordem de leitura do SQL.
    const missionIds = [...new Set(params.missionIds)].sort();
    const closed = await this.deps.repository.closeEligible(tx, {
      familyId: params.familyId,
      missionIds,
      now: params.now,
    });
    for (const mission of closed) {
      this.deps.logger.info('mission_closed', {
        missionId: mission.missionId,
        familyId: params.familyId,
        participationCount: mission.participationCount,
        badgesAwardedCount: mission.badgesAwardedCount,
        trigger: params.trigger,
      });
    }
    return closed.length;
  }

  /** Gancho de `CompleteTask`: reavalia as missões que vinculam a tarefa. */
  public async closeForCompletedTask(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly taskId: string; readonly now: Date },
  ): Promise<void> {
    const missionIds = await this.deps.repository.findMissionIdsByTask(
      tx,
      params.familyId,
      params.taskId,
    );
    await this.closeByIds(tx, {
      familyId: params.familyId,
      missionIds,
      now: params.now,
      trigger: 'completeTask',
    });
  }
}
