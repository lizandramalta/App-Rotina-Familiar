import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  ActionNotAllowedError,
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import { normalizeName } from '../domain/text-rules.js';
import type {
  FamilyProfile,
  FamilyProfileRepositoryPort,
} from './family-profile-repository-port.js';

function requireAdult(role: MemberRole | undefined): void {
  if (role === undefined) throw new NotFoundError('Family not found.');
  if (role === MemberRole.KIDS) throw new ActionNotAllowedError();
}

function requireAdministrator(role: MemberRole | undefined): void {
  if (role !== MemberRole.ADMINISTRATOR) throw new ActionNotAllowedError();
}

async function translateFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) throw error;
    throw new DependencyUnavailableError();
  }
}

export class GetFamilyUseCase {
  constructor(
    private readonly deps: {
      repository: FamilyProfileRepositoryPort;
      transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext): Promise<FamilyProfile> {
    requireAdult(actor.role);
    return translateFailure(() =>
      this.deps.transactionRunner.run(async (tx) => {
        requireAdult(await this.deps.repository.findActorRole(tx, actor.familyId, actor.memberId));
        const family = await this.deps.repository.findFamily(tx, actor.familyId);
        if (family === undefined) throw new NotFoundError('Family not found.');
        return family;
      }),
    );
  }
}

export class UpdateFamilyUseCase {
  constructor(
    private readonly deps: {
      repository: FamilyProfileRepositoryPort;
      transactionRunner: TransactionRunner;
      clock: Clock;
    },
  ) {}

  public async execute(actor: ActorContext, nameInput: unknown): Promise<FamilyProfile> {
    requireAdministrator(actor.role);
    let name: string | undefined;
    if (nameInput !== undefined) {
      const normalized = normalizeName(nameInput);
      if ('problem' in normalized) {
        throw new ValidationError('The family name is invalid.', {
          name: [`FAMILY_NAME_${normalized.problem}`],
        });
      }
      name = normalized.value;
    }
    return translateFailure(() =>
      this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        requireAdministrator(
          await this.deps.repository.findActorRole(tx, actor.familyId, actor.memberId),
        );
        const family = await this.deps.repository.lockFamily(tx, actor.familyId);
        if (family === undefined) throw new NotFoundError('Family not found.');
        return name === undefined || name === family.name
          ? family
          : this.deps.repository.updateName(tx, actor.familyId, name, this.deps.clock.now());
      }),
    );
  }
}
