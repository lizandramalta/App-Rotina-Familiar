import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import type { AccountDeletionRepositoryPort } from './account-deletion-ports.js';

/**
 * `DeleteKidsAccount` (UC20, SPEC-022 CA-16–CA-18, RN07/RN69).
 *
 * Somente Administrador, somente alvo Kids ativo da própria família. Alvo de
 * outra família, removido ou excluído é indistinguível de inexistente (RNF06).
 */
export class DeleteKidsAccountUseCase {
  constructor(
    private readonly deps: {
      readonly repository: AccountDeletionRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
      readonly logger: Logger;
    },
  ) {}

  public async execute(actor: ActorContext, memberId: string): Promise<void> {
    if (actor.role !== MemberRole.ADMINISTRATOR) throw new ActionNotAllowedError();

    try {
      await this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        // O papel persistido é revalidado sob o lock: a sessão pode estar defasada
        // (RNF07, BA-08).
        const administrator = await this.deps.repository.findActiveMember(tx, {
          familyId: actor.familyId,
          memberId: actor.memberId,
        });
        if (administrator?.role !== MemberRole.ADMINISTRATOR) throw new ActionNotAllowedError();

        const target = await this.deps.repository.findActiveMember(tx, {
          familyId: actor.familyId,
          memberId,
        });
        if (target === undefined) throw new NotFoundError('Family member not found.');
        if (target.role !== MemberRole.KIDS) throw new ActionNotAllowedError();

        await this.deps.repository.deleteMemberAccount(tx, {
          familyId: actor.familyId,
          memberId,
          now: this.deps.clock.now(),
        });
      });
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DependencyUnavailableError();
    }

    this.deps.logger.info('account_deleted', {
      role: MemberRole.KIDS,
      actor: 'administrator',
      familyDeleted: false,
    });
  }
}
