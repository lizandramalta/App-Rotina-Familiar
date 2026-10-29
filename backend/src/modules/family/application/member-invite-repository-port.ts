import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

export interface InviteActorState {
  readonly role: MemberRole;
  /** A sessão que autenticou o comando ainda não foi revogada. */
  readonly sessionActive: boolean;
}

export interface InviteTarget {
  readonly id: string;
  readonly isFamilyCreator: boolean;
}

/** Persistência da emissão de convite (SPEC-004 Fase 1). */
export interface MemberInviteRepositoryPort {
  /** Papel e sessão do ator relidos sob o lock de família (RNF07). */
  findActorState(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly sessionId: string;
    },
  ): Promise<InviteActorState | undefined>;

  /** Busca sempre no escopo da família: alvo externo equivale a inexistente. */
  findTarget(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<InviteTarget | undefined>;

  invalidateAvailableInvites(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly at: Date },
  ): Promise<void>;

  /** Revoga a sessão ativa do alvo, seus access tokens e seu dispositivo push. */
  revokeActiveSession(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly memberId: string;
      readonly reason: string;
    },
  ): Promise<void>;

  insertInvite(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly familyId: string;
      readonly memberId: string;
      readonly issuedByMemberId: string;
      readonly tokenHash: string;
      readonly passwordVerifier: string;
      readonly createdAt: Date;
    },
  ): Promise<void>;
}
