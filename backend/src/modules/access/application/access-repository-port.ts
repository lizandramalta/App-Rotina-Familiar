import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

/** Identidade Apple persistida, localizada pelo hash do `sub`. */
export interface CreatorIdentityRecord {
  readonly id: string;
  readonly appleSubjectHash: string;
}

/**
 * Vínculo do Criador com sua família. É a ÚNICA origem de `familyId` nesta rota
 * (CA-06): nada aqui vem da requisição.
 */
export interface CreatorMembershipRecord {
  readonly memberId: string;
  readonly familyId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
}

export interface InsertSessionParams {
  readonly sessionId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly refreshTokenHash: string;
  readonly installationProofHash: string;
}

export interface InsertAccessTokenParams {
  readonly accessTokenId: string;
  readonly sessionId: string;
  readonly tokenHash: string;
  readonly expiresAt: Date;
}

export interface InsertCreationGrantParams {
  readonly grantId: string;
  readonly creatorIdentityId: string;
  readonly grantTokenHash: string;
  readonly installationProofHash: string;
  readonly expiresAt: Date;
}

/**
 * Porta de persistência do módulo Access. Toda operação recebe o
 * `TransactionContext`, porque a revogação da sessão anterior e a criação da
 * nova precisam do mesmo commit (CA-05, RN44).
 */
export interface AccessRepositoryPort {
  findCreatorIdentityByAppleSubjectHash(
    tx: TransactionContext,
    appleSubjectHash: string,
  ): Promise<CreatorIdentityRecord | undefined>;

  insertCreatorIdentity(
    tx: TransactionContext,
    params: {
      readonly identityId: string;
      readonly appleSubjectHash: string;
      readonly appleSubjectEncrypted: string;
    },
  ): Promise<CreatorIdentityRecord>;

  findCreatorMembership(
    tx: TransactionContext,
    creatorIdentityId: string,
  ): Promise<CreatorMembershipRecord | undefined>;

  /**
   * Revoga toda sessão ativa do membro e devolve os ids revogados, para que o
   * caso de uso possa registrar a substituição (evento `session_revoked`).
   */
  revokeActiveSessionsForMember(
    tx: TransactionContext,
    params: { readonly memberId: string; readonly reason: string },
  ): Promise<string[]>;

  insertSession(tx: TransactionContext, params: InsertSessionParams): Promise<void>;

  insertAccessToken(tx: TransactionContext, params: InsertAccessTokenParams): Promise<void>;

  insertCreationGrant(tx: TransactionContext, params: InsertCreationGrantParams): Promise<void>;
}
