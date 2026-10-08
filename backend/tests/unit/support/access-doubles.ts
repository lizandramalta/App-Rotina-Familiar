/**
 * Dublês em memória do módulo Access, compartilhados pelos testes de unidade
 * dos casos de uso.
 *
 * O repositório mantém estado coerente (sessões, access tokens e membros), e não
 * apenas listas de chamadas: é isso que permite a um teste autenticar com o
 * token que outro passo emitiu, como a sequência real faria.
 */
import { createHash } from 'node:crypto';
import { vi } from 'vitest';
import type {
  AccessRepositoryPort,
  AccessTokenSessionRecord,
  CreatorIdentityRecord,
  CreatorMembershipRecord,
  InsertAccessTokenParams,
  InsertCreationGrantParams,
  InsertSessionParams,
  SessionRecord,
} from '../../../src/modules/access/application/access-repository-port.js';
import type { AccessCryptoPort } from '../../../src/modules/access/application/access-crypto-port.js';
import type { TransactionContext } from '../../../src/shared/application/transaction-runner.js';
import type { Logger } from '../../../src/shared/infrastructure/observability/logger.js';
import { MemberRole } from '../../../src/shared/domain/member-role.js';

/**
 * Digest real no dublê: um hash de brincadeira como `sha256(<token>)` conteria
 * o token e faria as asserções de não vazamento passarem por acidente.
 */
export const sha256Hex = (value: string): string =>
  createHash('sha256').update(value).digest('hex');

export interface StoredSession {
  readonly sessionId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly refreshTokenHash: string;
  readonly installationProofHash: string;
  revokedAt: Date | undefined;
  revokedReason: string | undefined;
  lastSeenAt: Date | undefined;
}

export interface StoredAccessToken {
  readonly tokenHash: string;
  readonly sessionId: string;
  readonly expiresAt: Date;
  revokedAt: Date | undefined;
}

/**
 * Repositório em memória. Registra também se cada escrita recebeu o mesmo
 * contexto de transação, para provar a atomicidade exigida por CA-05.
 */
export class InMemoryAccessRepository implements AccessRepositoryPort {
  public identities: CreatorIdentityRecord[] = [];
  public membership?: CreatorMembershipRecord;
  public activeSessionIds: string[] = [];
  public insertedSessions: InsertSessionParams[] = [];
  public insertedAccessTokens: InsertAccessTokenParams[] = [];
  public insertedGrants: InsertCreationGrantParams[] = [];
  public revokedWith: { memberId: string; reason: string }[] = [];
  public seenContexts: TransactionContext[] = [];
  /** Ordem das operações, para verificar que a revogação precede a inserção. */
  public operations: string[] = [];
  /** Membros consultáveis por `findSessionAndMemberByAccessTokenHash`. */
  public members: CreatorMembershipRecord[] = [];
  public sessions: StoredSession[] = [];
  public accessTokens: StoredAccessToken[] = [];

  public async findCreatorIdentityByAppleSubjectHash(
    tx: TransactionContext,
    appleSubjectHash: string,
  ): Promise<CreatorIdentityRecord | undefined> {
    this.seenContexts.push(tx);
    this.operations.push('findIdentity');
    return this.identities.find((identity) => identity.appleSubjectHash === appleSubjectHash);
  }

  public async insertCreatorIdentity(
    tx: TransactionContext,
    params: {
      readonly identityId: string;
      readonly appleSubjectHash: string;
      readonly appleSubjectEncrypted: string;
    },
  ): Promise<CreatorIdentityRecord> {
    this.seenContexts.push(tx);
    this.operations.push('insertIdentity');
    const record = { id: params.identityId, appleSubjectHash: params.appleSubjectHash };
    this.identities.push(record);
    return record;
  }

  public async findCreatorMembership(
    tx: TransactionContext,
  ): Promise<CreatorMembershipRecord | undefined> {
    this.seenContexts.push(tx);
    this.operations.push('findMembership');
    return this.membership;
  }

  public async revokeActiveSessionsForMember(
    tx: TransactionContext,
    params: { readonly memberId: string; readonly reason: string },
  ): Promise<string[]> {
    this.seenContexts.push(tx);
    this.operations.push('revokeSessions');
    this.revokedWith.push({ ...params });

    for (const session of this.sessions) {
      if (session.memberId === params.memberId && session.revokedAt === undefined) {
        session.revokedAt = new Date();
        session.revokedReason = params.reason;
      }
    }

    const revoked = [...this.activeSessionIds];
    this.activeSessionIds = [];
    return revoked;
  }

  public async insertSession(tx: TransactionContext, params: InsertSessionParams): Promise<void> {
    this.seenContexts.push(tx);
    this.operations.push('insertSession');
    this.insertedSessions.push(params);
    this.sessions.push({
      sessionId: params.sessionId,
      familyId: params.familyId,
      memberId: params.memberId,
      refreshTokenHash: params.refreshTokenHash,
      installationProofHash: params.installationProofHash,
      revokedAt: undefined,
      revokedReason: undefined,
      lastSeenAt: undefined,
    });
  }

  public async insertAccessToken(
    tx: TransactionContext,
    params: InsertAccessTokenParams,
  ): Promise<void> {
    this.seenContexts.push(tx);
    this.operations.push('insertAccessToken');
    this.insertedAccessTokens.push(params);
    this.accessTokens.push({
      tokenHash: params.tokenHash,
      sessionId: params.sessionId,
      expiresAt: params.expiresAt,
      revokedAt: undefined,
    });
  }

  public async insertCreationGrant(
    tx: TransactionContext,
    params: InsertCreationGrantParams,
  ): Promise<void> {
    this.seenContexts.push(tx);
    this.operations.push('insertCreationGrant');
    this.insertedGrants.push(params);
  }

  public async findSessionByRefreshTokenHash(
    tx: TransactionContext,
    refreshTokenHash: string,
  ): Promise<SessionRecord | undefined> {
    this.seenContexts.push(tx);
    this.operations.push('findSessionByRefreshToken');

    const session = this.sessions.find((item) => item.refreshTokenHash === refreshTokenHash);
    if (session === undefined) {
      return undefined;
    }

    return {
      sessionId: session.sessionId,
      familyId: session.familyId,
      memberId: session.memberId,
      installationProofHash: session.installationProofHash,
      revokedAt: session.revokedAt,
    };
  }

  public async findSessionAndMemberByAccessTokenHash(
    tx: TransactionContext,
    tokenHash: string,
  ): Promise<AccessTokenSessionRecord | undefined> {
    this.seenContexts.push(tx);
    this.operations.push('findSessionByAccessToken');

    const token = this.accessTokens.find((item) => item.tokenHash === tokenHash);
    if (token === undefined) {
      return undefined;
    }

    const session = this.sessions.find((item) => item.sessionId === token.sessionId);
    const member = this.members.find((item) => item.memberId === session?.memberId);
    if (session === undefined || member === undefined) {
      return undefined;
    }

    return {
      sessionId: session.sessionId,
      memberId: member.memberId,
      familyId: member.familyId,
      role: member.role,
      isFamilyCreator: member.isFamilyCreator,
      tokenExpiresAt: token.expiresAt,
      tokenRevokedAt: token.revokedAt,
      sessionRevokedAt: session.revokedAt,
    };
  }

  public async touchSessionLastSeen(tx: TransactionContext, sessionId: string): Promise<void> {
    this.seenContexts.push(tx);
    this.operations.push('touchSessionLastSeen');

    const session = this.sessions.find((item) => item.sessionId === sessionId);
    if (session !== undefined && session.revokedAt === undefined) {
      session.lastSeenAt = new Date();
    }
  }

  public async revokeSessionById(
    tx: TransactionContext,
    params: { readonly sessionId: string; readonly reason: string },
  ): Promise<boolean> {
    this.seenContexts.push(tx);
    this.operations.push('revokeSessionById');

    const session = this.sessions.find((item) => item.sessionId === params.sessionId);
    if (session === undefined || session.revokedAt !== undefined) {
      return false;
    }

    session.revokedAt = new Date();
    session.revokedReason = params.reason;
    return true;
  }

  public async revokeAccessTokensForSession(
    tx: TransactionContext,
    sessionId: string,
  ): Promise<void> {
    this.seenContexts.push(tx);
    this.operations.push('revokeAccessTokensForSession');

    for (const token of this.accessTokens) {
      if (token.sessionId === sessionId && token.revokedAt === undefined) {
        token.revokedAt = new Date();
      }
    }
  }
}

/** Crypto determinístico: os valores emitidos ficam previsíveis no teste. */
export function createFakeCrypto(): AccessCryptoPort & { issuedTokens: string[] } {
  let idCounter = 0;
  let tokenCounter = 0;
  const issuedTokens: string[] = [];

  return {
    issuedTokens,
    newId: () => `id-${++idCounter}`,
    generateOpaqueToken: () => {
      const token = `opaque-token-${++tokenCounter}`;
      issuedTokens.push(token);
      return token;
    },
    hashToken: sha256Hex,
    hashesMatch: (left, right) => left === right,
    hashAppleSubject: sha256Hex,
    encryptAppleSubject: (subject: string) => `enc(${sha256Hex(subject)})`,
  };
}

export function createSilentLogger(): Logger {
  const logger: Logger = {
    trace: vi.fn(),
    debug: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    fatal: vi.fn(),
    child: () => logger,
  };
  return logger;
}

export interface SeededSession {
  readonly sessionId: string;
  readonly memberId: string;
  readonly familyId: string;
  readonly refreshToken: string;
  readonly installationProof: string;
  readonly accessToken: string;
}

/**
 * Sessão ativa pronta no repositório, como `SignInWithApple` a teria deixado.
 * Os tokens entram em claro e são guardados como hash, igual ao caminho real.
 */
export function seedActiveSession(
  repository: InMemoryAccessRepository,
  overrides: Partial<SeededSession> & { readonly accessTokenExpiresAt: Date } & {
    readonly role?: MemberRole;
    readonly isFamilyCreator?: boolean;
  },
): SeededSession {
  const seeded: SeededSession = {
    sessionId: overrides.sessionId ?? 'session-seeded',
    memberId: overrides.memberId ?? 'member-seeded',
    familyId: overrides.familyId ?? 'family-seeded',
    refreshToken: overrides.refreshToken ?? 'refresh-token-seeded',
    installationProof: overrides.installationProof ?? 'installation-proof-seeded',
    accessToken: overrides.accessToken ?? 'access-token-seeded',
  };

  repository.members.push({
    memberId: seeded.memberId,
    familyId: seeded.familyId,
    role: overrides.role ?? MemberRole.ADMINISTRATOR,
    isFamilyCreator: overrides.isFamilyCreator ?? true,
  });

  repository.sessions.push({
    sessionId: seeded.sessionId,
    familyId: seeded.familyId,
    memberId: seeded.memberId,
    refreshTokenHash: sha256Hex(seeded.refreshToken),
    installationProofHash: sha256Hex(seeded.installationProof),
    revokedAt: undefined,
    revokedReason: undefined,
    lastSeenAt: undefined,
  });

  repository.accessTokens.push({
    tokenHash: sha256Hex(seeded.accessToken),
    sessionId: seeded.sessionId,
    expiresAt: overrides.accessTokenExpiresAt,
    revokedAt: undefined,
  });

  return seeded;
}
