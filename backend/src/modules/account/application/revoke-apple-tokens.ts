import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AppleTokenRevocationPort } from '../../../integrations/apple/apple-token-revocation-port.js';
import type { SecretCipherPort } from '../../access/application/secret-cipher-port.js';
import type {
  AppleTokenRevocationQueuePort,
  ClaimedAppleTokenRevocation,
} from './account-deletion-ports.js';
import { QUEUE_LEASE_MS, nextRetryDelayMs, sanitizedReason } from './post-commit-queue-policy.js';

const BATCH_SIZE = 20;

/**
 * Revogação pós-commit dos tokens Apple de famílias excluídas (SPEC-022 CA-13,
 * RN70, BA-40). Sucesso ou esgotamento das tentativas apagam o item e, com ele,
 * o token cifrado; falha transitória reagenda com atraso crescente. Nada aqui
 * desfaz a exclusão já confirmada.
 */
export class RevokeAppleTokens {
  constructor(
    private readonly deps: {
      readonly queue: AppleTokenRevocationQueuePort;
      readonly revocation: AppleTokenRevocationPort;
      readonly secretCipher: SecretCipherPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
      readonly newId: () => string;
      readonly maxAttempts: number;
    },
  ) {}

  /** Ciclo do worker: processa os itens vencidos. */
  public async run(): Promise<void> {
    const now = this.deps.clock.now();
    const claimId = this.deps.newId();
    const claimed = await this.deps.transactionRunner.run((tx) =>
      this.deps.queue.claimDue(tx, {
        now,
        claimId,
        leaseUntil: new Date(now.getTime() + QUEUE_LEASE_MS),
        limit: BATCH_SIZE,
      }),
    );

    for (const item of claimed) {
      await this.process(item, claimId);
    }
  }

  /**
   * Tentativa imediata logo após o commit da exclusão. Qualquer falha fica para
   * o worker; o chamador nunca recebe erro daqui.
   */
  public async processNow(id: string): Promise<void> {
    try {
      const now = this.deps.clock.now();
      const claimId = this.deps.newId();
      const item = await this.deps.transactionRunner.run((tx) =>
        this.deps.queue.claimById(tx, {
          id,
          now,
          claimId,
          leaseUntil: new Date(now.getTime() + QUEUE_LEASE_MS),
        }),
      );
      if (item !== undefined) {
        await this.process(item, claimId);
      }
    } catch (error) {
      this.deps.logger.warn('apple_token_revocation_deferred', { reason: sanitizedReason(error) });
    }
  }

  private async process(item: ClaimedAppleTokenRevocation, claimId: string): Promise<void> {
    const attempts = item.attempts + 1;

    let token: string;
    try {
      token = this.deps.secretCipher.decrypt(item.tokenEncrypted);
    } catch {
      // Valor ilegível (por exemplo, após troca de SESSION_SECRET) não melhora
      // com nova tentativa: o item é descartado e o fato fica registrado.
      await this.deps.transactionRunner.run((tx) =>
        this.deps.queue.complete(tx, { id: item.id, claimId }),
      );
      this.deps.logger.error('apple_token_revocation_failed', undefined, {
        attempt: attempts,
        reason: 'token_not_decryptable',
        exhausted: true,
      });
      return;
    }

    try {
      await this.deps.revocation.revokeToken(token, item.tokenTypeHint);
      await this.deps.transactionRunner.run((tx) =>
        this.deps.queue.complete(tx, { id: item.id, claimId }),
      );
      this.deps.logger.info('apple_token_revoked', { attempt: attempts });
    } catch (error) {
      const reason = sanitizedReason(error);
      if (attempts >= this.deps.maxAttempts) {
        await this.deps.transactionRunner.run((tx) =>
          this.deps.queue.complete(tx, { id: item.id, claimId }),
        );
        this.deps.logger.error('apple_token_revocation_failed', undefined, {
          attempt: attempts,
          reason,
          exhausted: true,
        });
        return;
      }

      const now = this.deps.clock.now();
      await this.deps.transactionRunner.run((tx) =>
        this.deps.queue.reschedule(tx, {
          id: item.id,
          claimId,
          attempts,
          nextAttemptAt: new Date(now.getTime() + nextRetryDelayMs(attempts)),
          lastError: reason,
        }),
      );
      this.deps.logger.warn('apple_token_revocation_failed', {
        attempt: attempts,
        reason,
        exhausted: false,
      });
    }
  }
}
