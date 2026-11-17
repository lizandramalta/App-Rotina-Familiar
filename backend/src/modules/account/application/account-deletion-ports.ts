import type { TransactionContext } from '../../../shared/application/transaction-runner.js';
import type { MemberRole } from '../../../shared/domain/member-role.js';
import type { AppleTokenTypeHint } from '../../../integrations/apple/apple-token-revocation-port.js';

/** Perfil ativo (não removido nem excluído) da família, relido sob o lock familiar. */
export interface DeletableMemberRecord {
  readonly id: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
}

/** Identidade Apple do Criador, com o refresh token cifrado quando houver. */
export interface CreatorAppleCredentials {
  readonly creatorIdentityId: string;
  readonly appleSubjectHash: string;
  readonly refreshTokenEncrypted: string | undefined;
}

/**
 * Persistência da exclusão de conta (SPEC-022, BA-40). Toda escrita ocorre dentro
 * da transação com lock familiar aberta pelo caso de uso; nenhuma chamada externa
 * (Apple, R2) acontece aqui.
 */
export interface AccountDeletionRepositoryPort {
  findActiveMember(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<DeletableMemberRecord | undefined>;

  findCreatorAppleCredentials(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string },
  ): Promise<CreatorAppleCredentials | undefined>;

  /**
   * Exclusão de perfil não-Criador (RN69): efeitos da remoção de RN10, revogação
   * com motivo próprio, anonimização e mídias do titular enfileiradas para o R2.
   */
  deleteMemberAccount(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly memberId: string; readonly now: Date },
  ): Promise<void>;

  /**
   * Exclusão física da família e da identidade Apple (RN70). As chaves de objeto
   * são gravadas na fila de limpeza antes de os registros serem apagados.
   */
  deleteFamily(
    tx: TransactionContext,
    params: { readonly familyId: string; readonly creatorIdentityId: string },
  ): Promise<{ readonly memberCount: number }>;

  enqueueAppleTokenRevocation(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly tokenEncrypted: string;
      readonly tokenTypeHint: AppleTokenTypeHint;
      readonly now: Date;
    },
  ): Promise<void>;
}

/** Item reivindicado de uma fila pós-commit, com o contador de tentativas atual. */
export interface ClaimedAppleTokenRevocation {
  readonly id: string;
  readonly tokenEncrypted: string;
  readonly tokenTypeHint: AppleTokenTypeHint;
  readonly attempts: number;
}

export interface ClaimedMediaObjectDeletion {
  readonly id: string;
  readonly objectKey: string;
  readonly attempts: number;
}

interface ClaimParams {
  readonly now: Date;
  readonly claimId: string;
  readonly leaseUntil: Date;
}

interface RescheduleParams {
  readonly id: string;
  readonly claimId: string;
  readonly attempts: number;
  readonly nextAttemptAt: Date;
  readonly lastError: string;
}

/** Fila de revogação de tokens Apple (BA-40). Atualizações exigem o claim vigente. */
export interface AppleTokenRevocationQueuePort {
  claimDue(
    tx: TransactionContext,
    params: ClaimParams & { readonly limit: number },
  ): Promise<ClaimedAppleTokenRevocation[]>;

  claimById(
    tx: TransactionContext,
    params: ClaimParams & { readonly id: string },
  ): Promise<ClaimedAppleTokenRevocation | undefined>;

  complete(
    tx: TransactionContext,
    params: { readonly id: string; readonly claimId: string },
  ): Promise<void>;

  reschedule(tx: TransactionContext, params: RescheduleParams): Promise<void>;
}

/** Fila de apagamento de objetos no R2 (BA-40). */
export interface MediaObjectDeletionQueuePort {
  claimDue(
    tx: TransactionContext,
    params: ClaimParams & { readonly limit: number },
  ): Promise<ClaimedMediaObjectDeletion[]>;

  /**
   * Remove o item e marca com `outcome` a mídia que ainda referencia a chave:
   * `DELETED` após o apagamento, `FAILED` quando as tentativas se esgotaram.
   */
  complete(
    tx: TransactionContext,
    params: {
      readonly id: string;
      readonly claimId: string;
      readonly objectKey: string;
      readonly outcome: 'DELETED' | 'FAILED';
    },
  ): Promise<void>;

  reschedule(tx: TransactionContext, params: RescheduleParams): Promise<void>;
}

/**
 * Limpeza do refresh token Apple de identidade que continua sem família depois
 * que todos os seus grants expiraram (SPEC-001 CA-13, E-12).
 */
export interface OrphanAppleTokenCleanupPort {
  clearTokensOfIdentitiesWithoutFamily(
    tx: TransactionContext,
    params: { readonly now: Date },
  ): Promise<number>;
}
