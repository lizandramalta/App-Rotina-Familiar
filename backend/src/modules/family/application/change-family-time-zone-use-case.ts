import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import { planTimeZoneChange, TimeZoneApplication } from '../domain/time-zone-change-planner.js';
import type { ChangeFamilyTimeZoneCommand, FamilySettingsView } from './family-settings-dto.js';
import type { FamilySettingsRepositoryPort } from './family-settings-repository-port.js';
import {
  assertAdministratorRole,
  assertTimeZoneDiffers,
  guardPersistence,
  loadSettledState,
  persistSettlement,
  toSettingsView,
  validateTimeZoneChange,
} from './family-settings-support.js';

/**
 * `ChangeFamilyTimeZone` (SPEC-002 Fase 3, CA-06 a CA-08).
 *
 * Os limites são recalculados no commit, sob o lock da família: a prévia não
 * reserva estado. Ciclos encerrados e datas civis nunca são tocados — só o ciclo
 * aberto (`immediate`) ou a programação para o seguinte (`nextCycle`). Uma nova
 * solicitação válida substitui a programada anterior (última gravação vence).
 */
export class ChangeFamilyTimeZoneUseCase {
  constructor(
    private readonly deps: {
      readonly repository: FamilySettingsRepositoryPort;
      readonly crypto: Pick<AccessCryptoPort, 'newId'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: ChangeFamilyTimeZoneCommand): Promise<FamilySettingsView> {
    const { actor } = command;
    assertAdministratorRole(actor);
    const change = validateTimeZoneChange(command);

    return guardPersistence(this.deps.logger, 'family_time_zone_change_failed', async () => {
      const result = await this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const { repository, crypto } = this.deps;
        const now = this.deps.clock.now();
        const state = await loadSettledState(repository, tx, actor, now);
        const previousTimeZoneId = state.settled.familyTimeZoneId;

        assertTimeZoneDiffers(change.timeZoneId, previousTimeZoneId);

        const plan = planTimeZoneChange({
          open: state.settled.open,
          timeZoneId: change.timeZoneId,
          application: change.application,
          now,
        });

        await persistSettlement({ repository, newId: () => crypto.newId() }, tx, actor, state, now);

        // Última solicitação válida vence: a programada pendente deixa de valer.
        if (state.pendingScheduled !== undefined) {
          await repository.resolveChange(tx, {
            changeId: state.pendingScheduled.id,
            status: 'SUPERSEDED',
            resolvedAt: now,
          });
        }

        const changeId = crypto.newId();
        const record = {
          changeId,
          familyId: actor.familyId,
          requestedByMemberId: actor.memberId,
          fromTimeZoneId: previousTimeZoneId,
          toTimeZoneId: plan.timeZoneId,
          application: plan.application,
          effectiveAt: plan.effectiveAt,
          requestedAt: now,
        };

        if (plan.application === TimeZoneApplication.IMMEDIATE) {
          await repository.updateCycleLimits(tx, {
            familyId: actor.familyId,
            startsAt: plan.effectiveLimits.startsAt,
            endsAt: plan.effectiveLimits.endsAt,
            timeZoneId: plan.timeZoneId,
            isTransition: true,
          });
          await repository.updateFamilyTimeZone(tx, {
            familyId: actor.familyId,
            timeZoneId: plan.timeZoneId,
            updatedAt: now,
          });
          await repository.insertChange(tx, { ...record, status: 'APPLIED' });

          return toSettingsView(state, {
            timeZoneId: plan.timeZoneId,
            open: plan.effectiveLimits,
            scheduled: undefined,
          });
        }

        await repository.insertChange(tx, { ...record, status: 'SCHEDULED' });

        return toSettingsView(state, {
          timeZoneId: previousTimeZoneId,
          open: state.settled.open,
          scheduled: { id: changeId, timeZoneId: plan.timeZoneId, effectiveAt: plan.effectiveAt },
        });
      });

      this.deps.logger.info('family_time_zone_changed', {
        familyId: actor.familyId,
        application: change.application,
      });

      return result;
    });
  }
}
