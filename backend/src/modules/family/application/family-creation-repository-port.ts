import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface CreationGrantRecord {
  readonly id: string;
  readonly creatorIdentityId: string;
  readonly installationProofHash: string;
}

/**
 * Porta de persistência da criação de família. Toda operação recebe o
 * `TransactionContext`: família, Criador, ciclo, consumo do grant e sessão
 * confirmam juntos ou não confirmam (CA-01, CA-03).
 */
export interface FamilyCreationRepositoryPort {
  findCreationGrantByTokenHash(
    tx: TransactionContext,
    grantTokenHash: string,
  ): Promise<CreationGrantRecord | undefined>;

  /**
   * Serializa criações concorrentes da mesma identidade (BA-08). O lock vive até
   * o fim da transação; o estado do grant e do vínculo é revalidado depois dele.
   */
  lockCreatorIdentity(tx: TransactionContext, creatorIdentityId: string): Promise<void>;

  hasFamilyMembership(tx: TransactionContext, creatorIdentityId: string): Promise<boolean>;

  /**
   * Consome o grant de forma atômica. `false` quando ele já foi consumido,
   * revogado ou expirou — inclusive entre a leitura e o lock.
   */
  consumeCreationGrant(
    tx: TransactionContext,
    params: { readonly grantId: string; readonly now: Date },
  ): Promise<boolean>;

  /** Grants restantes da identidade deixam de ser utilizáveis após a criação. */
  revokeOpenCreationGrants(
    tx: TransactionContext,
    params: { readonly creatorIdentityId: string; readonly now: Date },
  ): Promise<void>;

  insertFamily(
    tx: TransactionContext,
    params: {
      readonly familyId: string;
      readonly name: string;
      readonly timeZoneId: string;
      readonly createdAt: Date;
    },
  ): Promise<void>;

  insertCreatorMember(
    tx: TransactionContext,
    params: {
      readonly memberId: string;
      readonly familyId: string;
      readonly creatorIdentityId: string;
      readonly name: string;
      readonly nickname: string | null;
      readonly createdAt: Date;
    },
  ): Promise<void>;

  insertInitialMember(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly familyId: string;
      readonly name: string;
      readonly role: string;
      readonly createdAt: Date;
    },
  ): Promise<void>;

  insertWeeklyCycle(
    tx: TransactionContext,
    params: {
      readonly cycleId: string;
      readonly familyId: string;
      readonly startsAt: Date;
      readonly endsAt: Date;
      readonly timeZoneId: string;
      readonly referenceWeek: string;
    },
  ): Promise<void>;
}
