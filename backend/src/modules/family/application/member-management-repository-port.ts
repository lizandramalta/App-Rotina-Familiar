import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

export interface MemberRecord {
  readonly id: string;
  readonly name: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly createdAt: Date;
}

export interface MemberPageCursor {
  readonly createdAt: Date;
  readonly id: string;
}

/** Persistência do recorte de consulta e criação da SPEC-003 Fase 1. */
export interface MemberManagementRepositoryPort {
  findMembersPage(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly after: MemberPageCursor | undefined;
      readonly limit: number;
    },
  ): Promise<readonly MemberRecord[]>;

  findMember(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<MemberRecord | undefined>;

  /** Papel atual, relido sob o lock de família antes de uma escrita. */
  findMemberRole(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<MemberRole | undefined>;

  insertMember(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly familyId: string;
      readonly name: string;
      readonly role: MemberRole;
      readonly createdAt: Date;
    },
  ): Promise<MemberRecord>;
}
