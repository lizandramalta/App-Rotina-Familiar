import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import { planTimeZoneChange } from '../domain/time-zone-change-planner.js';
import type {
  ChangeFamilyTimeZoneCommand,
  TimeZoneChangePreviewView,
} from './family-settings-dto.js';
import type { FamilySettingsRepositoryPort } from './family-settings-repository-port.js';
import {
  assertAdministratorRole,
  assertTimeZoneDiffers,
  guardPersistence,
  loadSettledState,
  toLimitsView,
  validateTimeZoneChange,
} from './family-settings-support.js';

/**
 * `PreviewFamilyTimeZoneChange` (SPEC-002 Fase 3, CA-06/CA-07): mostra os
 * limites efetivos antes da confirmação. Só lê — a liquidação de ciclos vencidos
 * é calculada em memória e nenhuma linha é escrita nem reservada.
 */
export class PreviewFamilyTimeZoneChangeUseCase {
  constructor(
    private readonly deps: {
      readonly repository: FamilySettingsRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: ChangeFamilyTimeZoneCommand): Promise<TimeZoneChangePreviewView> {
    const { actor } = command;
    assertAdministratorRole(actor);
    const change = validateTimeZoneChange(command);

    return guardPersistence(this.deps.logger, 'family_time_zone_preview_failed', () =>
      this.deps.transactionRunner.run(async (tx) => {
        const now = this.deps.clock.now();
        const state = await loadSettledState(this.deps.repository, tx, actor, now);

        assertTimeZoneDiffers(change.timeZoneId, state.settled.familyTimeZoneId);

        const plan = planTimeZoneChange({
          open: state.settled.open,
          timeZoneId: change.timeZoneId,
          application: change.application,
          now,
        });

        return {
          proposedTimeZoneId: plan.timeZoneId,
          application: plan.application,
          effectiveAt: plan.effectiveAt.toISOString(),
          effectiveLimits: toLimitsView(plan.effectiveLimits),
          isTransition: plan.effectiveLimits.isTransition,
        };
      }),
    );
  }
}
