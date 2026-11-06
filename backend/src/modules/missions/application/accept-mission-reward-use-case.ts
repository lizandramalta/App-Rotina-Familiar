import type { ActorContext } from '../../../shared/application/actor-context.js';
import { DependencyUnavailableError, NotFoundError } from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import {
  MissionRewardAlreadyAcceptedError,
  MissionRewardPermissionError,
  MissionRewardRedemptionUnavailableError,
  RewardItemNotEligibleError,
} from '../domain/mission-errors.js';
import { validateRewardItemId } from '../domain/mission-validation.js';
import {
  assertUuid,
  deniedBy,
  requireAdministrator,
  toResponse,
  translateDependencyFailure,
  type Deps,
  type MissionResponse,
} from './mission-use-cases.js';
import type { RewardCatalogPort } from './reward-catalog-port.js';

export interface AcceptMissionRewardCommand {
  readonly actor: ActorContext;
  readonly missionId: string;
  readonly rewardItemId: unknown;
}

/** SPEC-017 Fase 1 / SCRUM-88, CA-01 a CA-05. */
export class AcceptMissionRewardUseCase {
  constructor(private readonly deps: Deps & { readonly rewardCatalog: RewardCatalogPort }) {}

  public async execute(command: AcceptMissionRewardCommand): Promise<MissionResponse> {
    const { actor } = command;
    // Recusa antecipada por perfil: Membro/Kids nem chegam a abrir transação.
    if (actor.role !== MemberRole.ADMINISTRATOR) {
      throw deniedBy(this.deps, actor, new MissionRewardPermissionError());
    }
    assertUuid(command.missionId);
    // Formato inválido nunca pode identificar item de outra família (CA-03):
    // falha antes de qualquer round-trip ao banco.
    const rewardItemId = validateRewardItemId(command.rewardItemId);

    return translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        await requireAdministrator(this.deps, tx, actor, () => new MissionRewardPermissionError());

        const mission = await this.deps.repository.findMission(
          tx,
          actor.familyId,
          command.missionId,
          true,
        );
        if (mission === undefined) {
          throw new NotFoundError('Mission not found.');
        }
        if (mission.completedAt === null) {
          throw new MissionRewardRedemptionUnavailableError();
        }
        if (mission.acceptedReward !== null) {
          throw new MissionRewardAlreadyAcceptedError();
        }

        const item = await this.deps.rewardCatalog.findEligibleItem(
          tx,
          actor.familyId,
          rewardItemId,
        );
        if (item === undefined) {
          throw new RewardItemNotEligibleError();
        }

        const now = this.deps.clock.now();
        const accepted = await this.deps.repository.acceptReward(tx, {
          familyId: actor.familyId,
          missionId: mission.id,
          reward: item,
          now,
        });
        if (!accepted) {
          // Sob o lock de família já serializado isto é inalcançável; mantido
          // como defesa, no mesmo estilo de `closeEligible`.
          throw new MissionRewardAlreadyAcceptedError();
        }

        const updated = await this.deps.repository.findMission(tx, actor.familyId, mission.id);
        if (updated === undefined) {
          throw new DependencyUnavailableError();
        }
        this.deps.logger.info('mission_reward_accepted', {
          missionId: mission.id,
          familyId: actor.familyId,
          rewardItemId,
          rewardSource: item.source,
        });
        return toResponse(updated);
      }),
    );
  }
}
