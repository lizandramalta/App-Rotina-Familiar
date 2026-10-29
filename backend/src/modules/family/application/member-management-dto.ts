import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

/** Projeção pública de um perfil da família (SPEC-003, Fase 1). */
export interface MemberView {
  readonly id: string;
  readonly name: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly createdAt: string;
}

export interface ListFamilyMembersResult {
  readonly items: readonly MemberView[];
  readonly nextCursor: string | null;
}

/** Detalhe adulto: a capacidade vem do ator autenticado, não do cliente. */
export interface MemberDetailView extends MemberView {
  readonly capabilities: {
    readonly manageMembers: boolean;
  };
}

export interface CreateMemberCommand {
  readonly actor: ActorContext;
  readonly name: unknown;
  readonly role: unknown;
}
