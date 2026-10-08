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
 * Sessão localizada pelo hash do refresh token (CA-08). `installationProofHash`
 * volta para o caso de uso comparar a prova apresentada; `revokedAt` distingue
 * sessão encerrada de sessão inexistente.
 */
export interface SessionRecord {
  readonly sessionId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly installationProofHash: string;
  readonly revokedAt: Date | undefined;
}

/**
 * Access token com a sessão e o membro a que pertence (CA-07, CA-09).
 *
 * Traz os três marcadores de invalidação separados — expiração do token,
 * revogação do token e revogação da sessão — porque a borda precisa responder
 * `SESSION_EXPIRED` ou `SESSION_REVOKED` conforme o caso (CA-05).
 */
export interface AccessTokenSessionRecord {
  readonly sessionId: string;
  readonly memberId: string;
  readonly familyId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly tokenExpiresAt: Date;
  readonly tokenRevokedAt: Date | undefined;
  readonly sessionRevokedAt: Date | undefined;
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

  /** Sessão pelo hash do refresh token, revogada ou não (CA-08). */
  findSessionByRefreshTokenHash(
    tx: TransactionContext,
    refreshTokenHash: string,
  ): Promise<SessionRecord | undefined>;

  /**
   * Access token com sessão e membro, revogados ou não: quem decide o erro é o
   * caso de uso, não a ausência de linha (CA-05, CA-07).
   */
  findSessionAndMemberByAccessTokenHash(
    tx: TransactionContext,
    tokenHash: string,
  ): Promise<AccessTokenSessionRecord | undefined>;

  /** Marca atividade da sessão na renovação (CA-08). */
  touchSessionLastSeen(tx: TransactionContext, sessionId: string): Promise<void>;

  /**
   * Revoga a sessão informada se ela ainda estiver ativa. Devolve `true` quando
   * revogou, para que o caso de uso só registre `session_revoked` uma vez.
   */
  revokeSessionById(
    tx: TransactionContext,
    params: { readonly sessionId: string; readonly reason: string },
  ): Promise<boolean>;

  /** Encerra os access tokens ativos da sessão, junto da revogação (CA-09). */
  revokeAccessTokensForSession(tx: TransactionContext, sessionId: string): Promise<void>;
}
