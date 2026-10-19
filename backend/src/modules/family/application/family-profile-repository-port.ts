import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

export interface FamilyProfile {
  readonly id: string;
  readonly name: string;
  readonly timeZoneId: string;
}

export interface FamilyProfileRepositoryPort {
  findFamily(tx: TransactionContext, familyId: string): Promise<FamilyProfile | undefined>;
  lockFamily(tx: TransactionContext, familyId: string): Promise<FamilyProfile | undefined>;
  findActorRole(
    tx: TransactionContext,
    familyId: string,
    memberId: string,
  ): Promise<MemberRole | undefined>;
  updateName(
    tx: TransactionContext,
    familyId: string,
    name: string,
    now: Date,
  ): Promise<FamilyProfile>;
}
