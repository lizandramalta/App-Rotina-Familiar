import type {
  TransactionContext,
  TransactionRunner,
} from '../../../shared/application/transaction-runner.js';
import type { FamilySettingsRepositoryPort } from '../../family/application/family-settings-repository-port.js';
import { settleCycles } from '../../family/domain/time-zone-change-planner.js';
import { selectWeeklyWinners } from '../domain/weekly-winners.js';
import type {
  FinalizeFamilyHighlightsPort,
  RecognitionRepositoryPort,
} from './recognition-repository-port.js';

/** SPEC-020 CA-01–04: calendário, resultado e outbox no mesmo commit familiar. */
export class FinalizeWeeklyHighlight implements FinalizeFamilyHighlightsPort {
  constructor(
    private readonly deps: {
      repository: RecognitionRepositoryPort;
      calendar: FamilySettingsRepositoryPort;
      transactionRunner: TransactionRunner;
      newId: () => string;
    },
  ) {}

  execute(familyId: string): Promise<number> {
    return this.deps.transactionRunner.forFamily(familyId, (tx) =>
      this.finalizeInTransaction(tx, familyId),
    );
  }

  async finalizeInTransaction(
    tx: TransactionContext,
    familyId: string,
    asOf?: Date,
  ): Promise<number> {
    const { repository, calendar } = this.deps;
    // clock_timestamp() após esperar o lock; o relógio do processo não decide elegibilidade.
    // Configurações de fuso compartilham o instante já obtido após o lock,
    // para não finalizar um ciclo diferente se a meia-noite ocorrer durante o comando.
    const now = asOf ?? (await repository.now(tx));
    const open = await calendar.findOpenCycle(tx, familyId);
    const familyTimeZoneId = await calendar.findFamilyTimeZone(tx, familyId);
    if (!open || !familyTimeZoneId) return 0;
    const scheduled = await calendar.findScheduledChange(tx, familyId);
    const settled = settleCycles({ open, familyTimeZoneId, scheduled, now });
    for (const cycle of settled.created) {
      await calendar.insertCycle(tx, { cycleId: this.deps.newId(), familyId, cycle });
    }
    if (settled.appliedScheduledId) {
      await calendar.updateFamilyTimeZone(tx, {
        familyId,
        timeZoneId: settled.familyTimeZoneId,
        updatedAt: now,
      });
      await calendar.resolveChange(tx, {
        changeId: settled.appliedScheduledId,
        status: 'APPLIED',
        resolvedAt: now,
      });
    }
    const cycles = await repository.findUnfinalizedCycles(tx, familyId, now);
    for (const cycle of cycles) {
      const winners = selectWeeklyWinners(await repository.scores(tx, familyId, cycle));
      await repository.saveFinalResult(tx, familyId, cycle, winners, now);
    }
    return cycles.length;
  }
}
