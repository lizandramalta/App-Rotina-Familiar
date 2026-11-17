import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { OrphanAppleTokenCleanupPort } from './account-deletion-ports.js';

/**
 * Apaga o refresh token Apple de identidades que continuam sem família depois
 * que seus grants de criação expiraram (SPEC-001 CA-13, E-12, RNF28). Roda junto
 * da limpeza de onboarding; um novo login guarda o token novamente.
 */
export class CleanOrphanAppleTokens {
  constructor(
    private readonly deps: {
      readonly cleanup: OrphanAppleTokenCleanupPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async run(): Promise<void> {
    const cleared = await this.deps.transactionRunner.run((tx) =>
      this.deps.cleanup.clearTokensOfIdentitiesWithoutFamily(tx, { now: this.deps.clock.now() }),
    );
    if (cleared > 0) {
      this.deps.logger.info('orphan_apple_tokens_cleared', { count: cleared });
    }
  }
}
