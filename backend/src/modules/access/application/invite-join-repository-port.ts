import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';

/** Convite localizado pelo hash do token, antes de qualquer lock. */
export interface InviteLookupRecord {
  readonly inviteId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly status: 'available' | 'invalidated' | 'consumed';
  readonly passwordVerifier: string;
}

/** Convite relido sob o lock da família, junto do perfil a que se destina. */
export interface LockedInviteRecord {
  readonly inviteId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly status: 'available' | 'invalidated' | 'consumed';
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
}

export interface InsertJoinRecoveryParams {
  readonly attemptId: string;
  readonly inviteId: string;
  readonly sessionId: string;
  readonly attemptSecretHash: string;
  readonly installationProofHash: string;
  readonly envelope: string;
  readonly createdAt: Date;
  readonly expiresAt: Date;
}

export interface JoinRecoveryRecord {
  readonly attemptId: string;
  readonly attemptSecretHash: string;
  readonly installationProofHash: string;
  readonly envelope: string;
  readonly expiresAt: Date;
  /** `true` somente quando a sessão ligada ao ingresso ainda não foi revogada. */
  readonly sessionActive: boolean;
}

/** Persistência do ingresso por convite (SPEC-005 Fase 1). */
export interface InviteJoinRepositoryPort {
  findInviteByTokenHash(
    tx: TransactionContext,
    tokenHash: string,
  ): Promise<InviteLookupRecord | undefined>;

  /** `FOR UPDATE` do convite: revalida estado e perfil depois de esperar o lock. */
  lockInviteForJoin(
    tx: TransactionContext,
    inviteId: string,
  ): Promise<LockedInviteRecord | undefined>;

  /** `true` quando consumiu; `false` se outro commit já o tinha consumido. */
  markInviteConsumed(
    tx: TransactionContext,
    params: { readonly inviteId: string; readonly at: Date },
  ): Promise<boolean>;

  /** `false` quando o `attemptId` já existe (a linha não é sobrescrita). */
  insertJoinRecovery(tx: TransactionContext, params: InsertJoinRecoveryParams): Promise<boolean>;

  /**
   * Remove os envelopes já vencidos de qualquer ingresso. O envelope guarda
   * credenciais de sessão: sem esta limpeza, quem nunca chama a recuperação
   * deixaria o resultado cifrado no banco depois da janela de dez minutos.
   */
  purgeExpiredJoinRecoveries(tx: TransactionContext, now: Date): Promise<void>;

  findJoinRecovery(
    tx: TransactionContext,
    attemptId: string,
  ): Promise<JoinRecoveryRecord | undefined>;

  deleteJoinRecovery(tx: TransactionContext, attemptId: string): Promise<void>;
}
