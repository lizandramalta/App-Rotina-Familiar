import { randomUUID } from 'node:crypto';
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
import { isValidMemberRole, MemberRole } from '../../../shared/domain/member-role.js';
import { normalizeName } from '../domain/text-rules.js';
import type {
  CreateMemberCommand,
  ListFamilyMembersResult,
  MemberDetailView,
  MemberView,
} from './member-management-dto.js';
import type {
  MemberManagementRepositoryPort,
  MemberPageCursor,
  MemberRecord,
} from './member-management-repository-port.js';

export const MEMBERS_PAGE_SIZE = 20;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function toMemberView(member: MemberRecord): MemberView {
  return {
    id: member.id,
    name: member.name,
    role: member.role,
    isFamilyCreator: member.isFamilyCreator,
    createdAt: member.createdAt.toISOString(),
  };
}

function requireAdult(actor: ActorContext): void {
  if (actor.role === MemberRole.KIDS) {
    throw new ActionNotAllowedError();
  }
}

function requireAdministrator(role: MemberRole | undefined): void {
  if (role !== MemberRole.ADMINISTRATOR) {
    throw new ActionNotAllowedError();
  }
}

function decodeCursor(cursor: string | undefined): MemberPageCursor | undefined {
  if (cursor === undefined) {
    return undefined;
  }

  try {
    const parsed: unknown = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      !('createdAt' in parsed) ||
      !('id' in parsed) ||
      typeof parsed.createdAt !== 'string' ||
      typeof parsed.id !== 'string'
    ) {
      throw new Error('invalid cursor');
    }
    const createdAt = new Date(parsed.createdAt);
    if (Number.isNaN(createdAt.getTime()) || !UUID_PATTERN.test(parsed.id)) {
      throw new Error('invalid cursor');
    }
    return { createdAt, id: parsed.id };
  } catch {
    throw new ValidationError('The member cursor is invalid.', { cursor: ['CURSOR_INVALID'] });
  }
}

/**
 * Uma falha de infraestrutura pode ocorrer depois de uma escrita confirmada no
 * banco e antes da resposta chegar ao cliente. O contrato expõe incerteza, não
 * sucesso nem uma promessa de rollback (SPEC-003 CA-07).
 */
async function translateDependencyFailure<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof DomainError) {
      throw error;
    }
    throw new DependencyUnavailableError();
  }
}

function encodeCursor(member: MemberRecord): string {
  return Buffer.from(
    JSON.stringify({ createdAt: member.createdAt.toISOString(), id: member.id }),
    'utf8',
  ).toString('base64url');
}

function validateName(input: unknown): string {
  const normalized = normalizeName(input);
  if ('value' in normalized) {
    return normalized.value;
  }
  throw new ValidationError('The member name is invalid.', {
    name: [`MEMBER_NAME_${normalized.problem}`],
  });
}

function validateRole(input: unknown): MemberRole {
  if (typeof input !== 'string' || !isValidMemberRole(input)) {
    throw new ValidationError('The member role is invalid.', { role: ['MEMBER_ROLE_INVALID'] });
  }
  return input;
}

export class ListFamilyMembersUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MemberManagementRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(
    actor: ActorContext,
    cursor: string | undefined,
  ): Promise<ListFamilyMembersResult> {
    requireAdult(actor);
    const after = decodeCursor(cursor);
    const records = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findMembersPage(tx, {
          familyId: actor.familyId,
          after,
          // Busca um registro extra para informar a continuidade sem totalizar a lista.
          limit: MEMBERS_PAGE_SIZE + 1,
        }),
      ),
    );
    const hasNextPage = records.length > MEMBERS_PAGE_SIZE;
    const items = records.slice(0, MEMBERS_PAGE_SIZE);
    const last = items.at(-1);
    return {
      items: items.map(toMemberView),
      nextCursor: hasNextPage && last !== undefined ? encodeCursor(last) : null,
    };
  }
}

export class GetMemberDetailUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MemberManagementRepositoryPort;
      readonly transactionRunner: TransactionRunner;
    },
  ) {}

  public async execute(actor: ActorContext, memberId: string): Promise<MemberDetailView> {
    requireAdult(actor);
    const member = await translateDependencyFailure(() =>
      this.deps.transactionRunner.run((tx) =>
        this.deps.repository.findMember(tx, { familyId: actor.familyId, memberId }),
      ),
    );
    if (member === undefined) {
      // O escopo da consulta torna membro externo indistinguível de inexistente.
      throw new NotFoundError('Family member not found.');
    }
    return {
      ...toMemberView(member),
      capabilities: { manageMembers: actor.role === MemberRole.ADMINISTRATOR },
    };
  }
}

export class CreateMemberUseCase {
  constructor(
    private readonly deps: {
      readonly repository: MemberManagementRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  public async execute(command: CreateMemberCommand): Promise<MemberView> {
    requireAdministrator(command.actor.role);
    const name = validateName(command.name);
    const role = validateRole(command.role);

    return translateDependencyFailure(() =>
      this.deps.transactionRunner.forFamily(command.actor.familyId, async (tx) => {
        // A sessão pode ter ficado defasada enquanto aguardava o lock; revalida-se
        // o papel persistido antes da inserção (RNF07 / BA-08).
        requireAdministrator(
          await this.deps.repository.findMemberRole(tx, {
            familyId: command.actor.familyId,
            memberId: command.actor.memberId,
          }),
        );
        const member = await this.deps.repository.insertMember(tx, {
          id: randomUUID(),
          familyId: command.actor.familyId,
          name,
          role,
          createdAt: this.deps.clock.now(),
        });
        return toMemberView(member);
      }),
    );
  }
}
