import { randomUUID } from 'node:crypto';
import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import type { Logger } from '../../../shared/infrastructure/observability/logger.js';
import { SessionRevokedError } from '../../access/domain/access-errors.js';
import { RewardPermissionError, RewardTitleAlreadyExistsError } from '../domain/reward-errors.js';
import { validateRewardDetails, validateRewardTitle } from '../domain/reward-validation.js';
import type { RewardItemRecord, RewardRepositoryPort } from './reward-repository-port.js';

export interface RewardItemResponse {
  readonly id: string;
  readonly title: string;
  readonly details: string | null;
  readonly source: 'predefined' | 'custom';
  readonly createdAt?: string;
}

export interface RewardCatalogResponse {
  readonly predefined: readonly RewardItemResponse[];
  readonly custom: readonly RewardItemResponse[];
}

interface Deps {
  readonly repository: RewardRepositoryPort;
  readonly transactionRunner: TransactionRunner;
  readonly logger: Logger;
}

function project(record: RewardItemRecord): RewardItemResponse {
  return record.source === 'custom'
    ? {
        id: record.id,
        title: record.title,
        details: record.details,
        source: 'custom',
        createdAt: record.createdAt.toISOString(),
      }
    : { id: record.id, title: record.title, details: record.details, source: 'predefined' };
}

function requireAdministrator(actor: ActorContext): void {
  if (actor.role !== MemberRole.ADMINISTRATOR) throw new RewardPermissionError();
}

async function requireCurrentAdministrator(
  repository: RewardRepositoryPort,
  tx: TransactionContext,
  actor: ActorContext,
): Promise<void> {
  const role = await repository.findActorRole(tx, actor);
  if (role === undefined) throw new SessionRevokedError();
  if (role !== MemberRole.ADMINISTRATOR) throw new RewardPermissionError();
}

async function translateFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) throw error;
    throw new DependencyUnavailableError();
  }
}

/** SPEC-015 CA-01/05/06: catálogo administrativo sem familyId externo. */
export class ListRewardItemsUseCase {
  constructor(private readonly deps: Deps) {}

  public async execute(actor: ActorContext): Promise<RewardCatalogResponse> {
    try {
      requireAdministrator(actor);
      const result = await translateFailure(async () => {
        const items = await this.deps.transactionRunner.run(async (tx) => {
          await requireCurrentAdministrator(this.deps.repository, tx, actor);
          return this.deps.repository.listItems(tx, actor.familyId);
        });
        return {
          predefined: items.filter((item) => item.source === 'predefined').map(project),
          custom: items.filter((item) => item.source === 'custom').map(project),
        };
      });
      this.deps.logger.info('reward_items_list_result', { outcome: 'success' });
      return result;
    } catch (error) {
      this.deps.logger.warn('reward_items_list_result', {
        outcome: 'failed',
        code: error instanceof DomainError ? error.code : 'UNKNOWN',
      });
      throw error;
    }
  }
}

/** SPEC-015 CA-02/03/04/05: criação curta, serializada e com unicidade no banco. */
export class AddRewardItemUseCase {
  constructor(private readonly deps: Deps & { readonly clock: Clock }) {}

  public async execute(command: {
    readonly actor: ActorContext;
    readonly title: unknown;
    readonly details: unknown;
  }): Promise<RewardItemResponse> {
    try {
      const { actor } = command;
      requireAdministrator(actor);
      const { title, normalizedTitle } = validateRewardTitle(command.title);
      const details = validateRewardDetails(command.details);
      const created = await translateFailure(() =>
        this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
          await requireCurrentAdministrator(this.deps.repository, tx, actor);
          return this.deps.repository.insertCustom(tx, {
            id: randomUUID(),
            familyId: actor.familyId,
            createdById: actor.memberId,
            title,
            normalizedTitle,
            details,
            createdAt: this.deps.clock.now(),
          });
        }),
      );
      this.deps.logger.info('reward_item_add_result', { outcome: 'created' });
      return project(created);
    } catch (error) {
      this.deps.logger.warn('reward_item_add_result', {
        outcome:
          error instanceof RewardTitleAlreadyExistsError
            ? 'duplicate'
            : error instanceof ValidationError
              ? 'validation_failed'
              : error instanceof RewardPermissionError
                ? 'denied'
                : 'failed',
        code: error instanceof DomainError ? error.code : 'UNKNOWN',
      });
      throw error;
    }
  }
}
