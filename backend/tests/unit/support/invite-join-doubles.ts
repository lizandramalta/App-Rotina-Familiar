/**
 * Dublês em memória do ingresso por convite. Mantêm estado coerente (convites,
 * recuperações, contagem de tentativas), para que um teste encadeie ingresso e
 * recuperação como a sequência real faria.
 */
import type { InviteAttemptLimiterPort } from '../../../src/modules/access/application/invite-attempt-limiter-port.js';
import type {
  InsertJoinRecoveryParams,
  InviteJoinRepositoryPort,
  InviteLookupRecord,
  JoinRecoveryRecord,
  LockedInviteRecord,
} from '../../../src/modules/access/application/invite-join-repository-port.js';
import type { TransactionContext } from '../../../src/shared/application/transaction-runner.js';
import { MemberRole } from '../../../src/shared/domain/member-role.js';
import { sha256Hex, type InMemoryAccessRepository } from './access-doubles.js';

export interface StoredInvite {
  inviteId: string;
  familyId: string;
  memberId: string;
  status: 'available' | 'invalidated' | 'consumed';
  tokenHash: string;
  passwordVerifier: string;
  role: MemberRole;
  isFamilyCreator: boolean;
}

export class InMemoryInviteJoinRepository implements InviteJoinRepositoryPort {
  public invites: StoredInvite[] = [];
  public recoveries: (InsertJoinRecoveryParams & { sessionId: string })[] = [];
  /** Permite simular a falha da escrita final para provar o rollback. */
  public failOnInsertRecovery = false;

  constructor(private readonly accessRepository: InMemoryAccessRepository) {}

  public async findInviteByTokenHash(
    _tx: TransactionContext,
    tokenHash: string,
  ): Promise<InviteLookupRecord | undefined> {
    const invite = this.invites.find((item) => item.tokenHash === tokenHash);
    return invite === undefined
      ? undefined
      : {
          inviteId: invite.inviteId,
          familyId: invite.familyId,
          memberId: invite.memberId,
          status: invite.status,
          passwordVerifier: invite.passwordVerifier,
        };
  }

  public async lockInviteForJoin(
    _tx: TransactionContext,
    inviteId: string,
  ): Promise<LockedInviteRecord | undefined> {
    const invite = this.invites.find((item) => item.inviteId === inviteId);
    return invite === undefined
      ? undefined
      : {
          inviteId: invite.inviteId,
          familyId: invite.familyId,
          memberId: invite.memberId,
          status: invite.status,
          role: invite.role,
          isFamilyCreator: invite.isFamilyCreator,
        };
  }

  public async markInviteConsumed(
    _tx: TransactionContext,
    params: { readonly inviteId: string; readonly at: Date },
  ): Promise<boolean> {
    const invite = this.invites.find((item) => item.inviteId === params.inviteId);
    if (invite === undefined || invite.status !== 'available') {
      return false;
    }
    invite.status = 'consumed';
    return true;
  }

  public async insertJoinRecovery(
    _tx: TransactionContext,
    params: InsertJoinRecoveryParams,
  ): Promise<boolean> {
    if (this.failOnInsertRecovery) {
      throw new Error('simulated database failure');
    }
    if (this.recoveries.some((item) => item.attemptId === params.attemptId)) {
      return false;
    }
    this.recoveries.push({ ...params });
    return true;
  }

  public async purgeExpiredJoinRecoveries(_tx: TransactionContext, now: Date): Promise<void> {
    this.recoveries = this.recoveries.filter((item) => item.expiresAt.getTime() > now.getTime());
  }

  public async findJoinRecovery(
    _tx: TransactionContext,
    attemptId: string,
  ): Promise<JoinRecoveryRecord | undefined> {
    const recovery = this.recoveries.find((item) => item.attemptId === attemptId);
    if (recovery === undefined) {
      return undefined;
    }
    const session = this.accessRepository.sessions.find(
      (item) => item.sessionId === recovery.sessionId,
    );
    return {
      attemptId: recovery.attemptId,
      attemptSecretHash: recovery.attemptSecretHash,
      installationProofHash: recovery.installationProofHash,
      envelope: recovery.envelope,
      expiresAt: recovery.expiresAt,
      sessionActive: session !== undefined && session.revokedAt === undefined,
    };
  }

  public async deleteJoinRecovery(_tx: TransactionContext, attemptId: string): Promise<void> {
    this.recoveries = this.recoveries.filter((item) => item.attemptId !== attemptId);
  }
}

/** Limiter que conta como o real: registra e compara com o limite. */
export class InMemoryInviteAttemptLimiter implements InviteAttemptLimiterPort {
  public readonly counts = new Map<string, number>();
  public throwOnUse = false;

  public async recordAndCheckExceeded(params: {
    readonly scope: 'invite' | 'origin';
    readonly subjectHash: string;
    readonly limit: number;
  }): Promise<boolean> {
    if (this.throwOnUse) {
      throw new Error('simulated limiter failure');
    }
    const key = `${params.scope}:${params.subjectHash}`;
    const next = (this.counts.get(key) ?? 0) + 1;
    this.counts.set(key, next);
    return next > params.limit;
  }

  public countFor(scope: 'invite' | 'origin', subject: string): number {
    return this.counts.get(`${scope}:${sha256Hex(subject)}`) ?? 0;
  }
}
