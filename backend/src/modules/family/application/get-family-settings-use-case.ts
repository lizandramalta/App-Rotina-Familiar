import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccessCryptoPort } from '../../access/application/access-crypto-port.js';
import type { FamilySettingsView, GetFamilySettingsCommand } from './family-settings-dto.js';
import type { FamilySettingsRepositoryPort } from './family-settings-repository-port.js';
import {
  assertAdministratorRole,
  guardPersistence,
  loadSettledState,
  persistSettlement,
  toSettingsView,
} from './family-settings-support.js';

/**
 * `GetFamilySettings` (SPEC-002 Fase 3, CA-05): fuso vigente, mudança
 * programada e limites do ciclo atual, só para Administradores.
 *
 * Roda sob o lock da família porque liquida ciclos vencidos antes de responder
 * (decisões E-07/E-08): sem worker, a leitura é o primeiro momento em que o
 * encerramento de um ciclo é observado.
 */
export class GetFamilySettingsUseCase {
  constructor(
    private readonly deps: {
      readonly repository: FamilySettingsRepositoryPort;
      readonly crypto: Pick<AccessCryptoPort, 'newId'>;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(command: GetFamilySettingsCommand): Promise<FamilySettingsView> {
    const { actor } = command;
    assertAdministratorRole(actor);

    return guardPersistence(this.deps.logger, 'family_settings_read_failed', () =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const now = this.deps.clock.now();
        const state = await loadSettledState(this.deps.repository, tx, actor, now);

        await persistSettlement(
          { repository: this.deps.repository, newId: () => this.deps.crypto.newId() },
          tx,
          actor,
          state,
          now,
        );

        return toSettingsView(state);
      }),
    );
  }
}
