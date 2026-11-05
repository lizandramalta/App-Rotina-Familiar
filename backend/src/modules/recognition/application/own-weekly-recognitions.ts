import type { ActorContext } from '../../../shared/application/actor-context.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
} from '../../../shared/domain/domain-error.js';
import type { RecognitionRepositoryPort } from './recognition-repository-port.js';

/** SPEC-020 CA-05/06: titularidade revalidada depois do lock, sem depender do push. */
export class OwnWeeklyRecognitions {
  constructor(
    private readonly repository: RecognitionRepositoryPort,
    private readonly transactions: TransactionRunner,
  ) {}

  private async authorized<T>(
    actor: ActorContext,
    work: (tx: TransactionContext) => Promise<T>,
  ): Promise<T> {
    try {
      return await this.transactions.forFamily(actor.familyId, async (tx) => {
        await this.repository.requireActiveSession(tx, actor);
        return work(tx);
      });
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DependencyUnavailableError();
    }
  }

  list(actor: ActorContext) {
    return this.authorized(actor, async (tx) => ({
      items: await this.repository.listOwn(tx, actor),
    }));
  }

  get(actor: ActorContext, id: string) {
    return this.authorized(actor, async (tx) => {
      const result = await this.repository.findOwn(tx, actor, id);
      if (!result) throw new NotFoundError('Recognition not found.');
      return result;
    });
  }

  open(actor: ActorContext, id: string) {
    return this.authorized(actor, async (tx) => {
      await this.repository.openOwn(tx, actor, id);
      const result = await this.repository.findOwn(tx, actor, id);
      if (!result) throw new NotFoundError('Recognition not found.');
      return result;
    });
  }
}
