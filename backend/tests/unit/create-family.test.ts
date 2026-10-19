/**
 * Caso de uso `CreateFamily` — SPEC-002 Fase 1: CA-01 a CA-04 e CA-09.
 *
 * O repositório é um dublê em memória com rollback real: o que está sob teste é
 * a orquestração (grant, atomicidade, validação, isolamento e falha incerta).
 * A unicidade e os locks do banco são provados em tests/integration.
 */
import { createHash } from 'node:crypto';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { AccessCryptoPort } from '../../src/modules/access/application/access-crypto-port.js';
import type {
  AccessRepositoryPort,
  InsertAccessTokenParams,
  InsertSessionParams,
} from '../../src/modules/access/application/access-repository-port.js';
import { SessionIssuer } from '../../src/modules/access/application/session-issuer.js';
import { CreateFamilyUseCase } from '../../src/modules/family/application/create-family-use-case.js';
import type { CreateFamilyCommand } from '../../src/modules/family/application/create-family-dto.js';
import type {
  CreationGrantRecord,
  FamilyCreationRepositoryPort,
} from '../../src/modules/family/application/family-creation-repository-port.js';
import { CreationGrantInvalidError } from '../../src/modules/family/domain/family-errors.js';
import type { OnboardingMediaPort } from '../../src/modules/media/application/onboarding-media-port.js';
import type { Clock } from '../../src/shared/application/clock.js';
import type {
  TransactionContext,
  TransactionRunner,
} from '../../src/shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  ValidationError,
} from '../../src/shared/domain/domain-error.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');

const FIXED_NOW = new Date('2026-10-08T12:00:00.000Z');
const INSTALLATION_PROOF = 'installation-proof-opaque';
const GRANT = 'opaque-creation-grant';
const IDENTITY_ID = 'identity-1';

interface FamilyRow {
  id: string;
  name: string;
  timeZoneId: string;
  createdAt: Date;
}
interface MemberRow {
  id: string;
  familyId: string;
  creatorIdentityId: string;
  name: string;
  nickname: string | null;
}
interface CycleRow {
  familyId: string;
  startsAt: Date;
  endsAt: Date;
  timeZoneId: string;
  referenceWeek: string;
}
interface GrantState extends CreationGrantRecord {
  expiresAt: Date;
  consumedAt?: Date;
  revokedAt?: Date;
}

interface Snapshot {
  families: FamilyRow[];
  members: MemberRow[];
  cycles: CycleRow[];
  grants: GrantState[];
  sessions: InsertSessionParams[];
  accessTokens: InsertAccessTokenParams[];
}

/** Armazenamento único para família e acesso, com snapshot para o rollback. */
class InMemoryDatabase implements FamilyCreationRepositoryPort, AccessRepositoryPort {
  public families: FamilyRow[] = [];
  public members: MemberRow[] = [];
  public cycles: CycleRow[] = [];
  public grants: GrantState[] = [];
  public sessions: InsertSessionParams[] = [];
  public accessTokens: InsertAccessTokenParams[] = [];
  public lockedIdentities: string[] = [];
  public failOn?: 'insertFamily' | 'insertInitialMember' | 'insertSession';
  public seenContexts = new Set<TransactionContext>();

  public snapshot(): Snapshot {
    return structuredClone({
      families: this.families,
      members: this.members,
      cycles: this.cycles,
      grants: this.grants,
      sessions: this.sessions,
      accessTokens: this.accessTokens,
    });
  }

  public restore(snapshot: Snapshot): void {
    Object.assign(this, snapshot);
  }

  public addGrant(grantToken: string, overrides: Partial<GrantState> = {}): GrantState {
    const grant: GrantState = {
      id: `grant-${this.grants.length + 1}`,
      creatorIdentityId: IDENTITY_ID,
      installationProofHash: sha256(INSTALLATION_PROOF),
      expiresAt: new Date(FIXED_NOW.getTime() + 10 * 60 * 1000),
      ...overrides,
      // O hash do token fica à parte para a busca; guardado no próprio registro.
    };
    (grant as GrantState & { tokenHash: string }).tokenHash = sha256(grantToken);
    this.grants.push(grant);
    return grant;
  }

  public async findCreationGrantByTokenHash(
    tx: TransactionContext,
    grantTokenHash: string,
  ): Promise<CreationGrantRecord | undefined> {
    this.seenContexts.add(tx);
    return this.grants.find(
      (grant) => (grant as GrantState & { tokenHash: string }).tokenHash === grantTokenHash,
    );
  }

  public async lockCreatorIdentity(tx: TransactionContext, identityId: string): Promise<void> {
    this.seenContexts.add(tx);
    this.lockedIdentities.push(identityId);
  }

  public async hasFamilyMembership(tx: TransactionContext, identityId: string): Promise<boolean> {
    this.seenContexts.add(tx);
    return this.members.some((member) => member.creatorIdentityId === identityId);
  }

  public async consumeCreationGrant(
    tx: TransactionContext,
    params: { grantId: string; now: Date },
  ): Promise<boolean> {
    this.seenContexts.add(tx);
    const grant = this.grants.find((candidate) => candidate.id === params.grantId);
    if (
      grant === undefined ||
      grant.consumedAt !== undefined ||
      grant.revokedAt !== undefined ||
      grant.expiresAt <= params.now
    ) {
      return false;
    }
    grant.consumedAt = params.now;
    return true;
  }

  public async revokeOpenCreationGrants(
    tx: TransactionContext,
    params: { creatorIdentityId: string; now: Date },
  ): Promise<void> {
    this.seenContexts.add(tx);
    for (const grant of this.grants) {
      if (
        grant.creatorIdentityId === params.creatorIdentityId &&
        grant.consumedAt === undefined &&
        grant.revokedAt === undefined
      ) {
        grant.revokedAt = params.now;
      }
    }
  }

  public async insertFamily(
    tx: TransactionContext,
    params: { familyId: string; name: string; timeZoneId: string; createdAt: Date },
  ): Promise<void> {
    this.seenContexts.add(tx);
    if (this.failOn === 'insertFamily') {
      throw new Error('connection terminated unexpectedly');
    }
    this.families.push({
      id: params.familyId,
      name: params.name,
      timeZoneId: params.timeZoneId,
      createdAt: params.createdAt,
    });
  }

  public async insertCreatorMember(
    tx: TransactionContext,
    params: {
      memberId: string;
      familyId: string;
      creatorIdentityId: string;
      name: string;
      nickname: string | null;
    },
  ): Promise<void> {
    this.seenContexts.add(tx);
    this.members.push({
      id: params.memberId,
      familyId: params.familyId,
      creatorIdentityId: params.creatorIdentityId,
      name: params.name,
      nickname: params.nickname,
    });
  }

  public async insertWeeklyCycle(
    tx: TransactionContext,
    params: CycleRow & { cycleId: string },
  ): Promise<void> {
    this.seenContexts.add(tx);
    this.cycles.push({
      familyId: params.familyId,
      startsAt: params.startsAt,
      endsAt: params.endsAt,
      timeZoneId: params.timeZoneId,
      referenceWeek: params.referenceWeek,
    });
  }

  public async insertInitialMember(
    tx: TransactionContext,
    params: { id: string; familyId: string; name: string; role: string },
  ): Promise<void> {
    this.seenContexts.add(tx);
    if (this.failOn === 'insertInitialMember') throw new Error('member insert failed');
    this.members.push({
      id: params.id,
      familyId: params.familyId,
      creatorIdentityId: '',
      name: params.name,
      nickname: null,
    });
  }

  // --- AccessRepositoryPort: só o que o SessionIssuer usa ---------------------
  public async revokeActiveSessionsForMember(tx: TransactionContext): Promise<string[]> {
    this.seenContexts.add(tx);
    return [];
  }

  public async insertSession(tx: TransactionContext, params: InsertSessionParams): Promise<void> {
    this.seenContexts.add(tx);
    if (this.failOn === 'insertSession') {
      throw new Error('connection terminated unexpectedly');
    }
    this.sessions.push(params);
  }

  public async insertAccessToken(
    tx: TransactionContext,
    params: InsertAccessTokenParams,
  ): Promise<void> {
    this.seenContexts.add(tx);
    this.accessTokens.push(params);
  }

  public async findCreatorIdentityByAppleSubjectHash(): Promise<undefined> {
    return undefined;
  }
  public async insertCreatorIdentity(): Promise<never> {
    throw new Error('not used');
  }
  public async findCreatorMembership(): Promise<undefined> {
    return undefined;
  }
  public async insertCreationGrant(): Promise<void> {
    throw new Error('not used');
  }
  public async findSessionByRefreshTokenHash(): Promise<undefined> {
    return undefined;
  }
  public async findSessionAndMemberByAccessTokenHash(): Promise<undefined> {
    return undefined;
  }
  public async touchSessionLastSeen(): Promise<void> {}
  public async revokeSessionById(): Promise<boolean> {
    return true;
  }
  public async revokeAccessTokensForSession(): Promise<void> {}
  public async revokePushDevicesForSession(): Promise<void> {}
}

class RollbackTransactionRunner implements TransactionRunner {
  public runs = 0;
  constructor(private readonly database: InMemoryDatabase) {}

  public async run<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T> {
    this.runs += 1;
    const snapshot = this.database.snapshot();
    try {
      return await work({ client: {} });
    } catch (error) {
      this.database.restore(snapshot);
      throw error;
    }
  }

  public async forFamily<T>(
    _familyId: string,
    work: (tx: TransactionContext) => Promise<T>,
  ): Promise<T> {
    return this.run(work);
  }
}

let counter = 0;
const crypto: AccessCryptoPort = {
  newId: () => `id-${++counter}`,
  generateOpaqueToken: () => `opaque-token-${++counter}`,
  hashToken: sha256,
  hashAppleSubject: sha256,
  encryptAppleSubject: (value) => `enc(${value})`,
  hashesMatch: (left, right) => left === right,
};
const clock: Clock = { now: () => FIXED_NOW, nowIsoString: () => FIXED_NOW.toISOString() };

const VALID_COMMAND: CreateFamilyCommand = {
  creationGrant: GRANT,
  creatorName: 'Maria Silva',
  creatorNickname: 'Mari',
  name: 'Casa Silva',
  timeZoneId: 'America/Sao_Paulo',
  installationProof: INSTALLATION_PROOF,
};

describe('CreateFamilyUseCase', () => {
  let database: InMemoryDatabase;
  let runner: RollbackTransactionRunner;
  let useCase: CreateFamilyUseCase;
  let logCalls: unknown[][];
  let onboardingMedia: {
    findForGrant: ReturnType<typeof vi.fn>;
    findById: ReturnType<typeof vi.fn>;
    transferToCreator: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    counter = 0;
    database = new InMemoryDatabase();
    database.addGrant(GRANT);
    runner = new RollbackTransactionRunner(database);

    const { logger, calls } = createRecordingLogger();
    logCalls = calls;
    onboardingMedia = {
      findForGrant: vi.fn().mockResolvedValue(undefined),
      findById: vi.fn().mockResolvedValue(undefined),
      transferToCreator: vi.fn(),
    };

    useCase = new CreateFamilyUseCase({
      repository: database,
      onboardingMedia: onboardingMedia as unknown as OnboardingMediaPort,
      sessionIssuer: new SessionIssuer({ repository: database, crypto, logger }),
      crypto,
      transactionRunner: runner,
      clock,
      logger,
    });
  });

  describe('CA-01: creation with a valid grant', () => {
    const photoId = '9f1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';

    it('links only a READY photo of the same grant in the creation transaction', async () => {
      const photo = {
        id: photoId,
        grantId: 'grant-1',
        purpose: 'PROFILE_PHOTO',
        state: 'READY',
        objectKey: 'private/photo.jpg',
        sizeBytes: 4,
        contentType: 'image/jpeg',
      };
      onboardingMedia.findForGrant.mockResolvedValue(photo);
      const result = await useCase.execute({ ...VALID_COMMAND, creatorPhotoMediaId: photoId });
      expect(onboardingMedia.findForGrant).toHaveBeenCalledWith(
        expect.anything(),
        photoId,
        'grant-1',
      );
      expect(onboardingMedia.transferToCreator).toHaveBeenCalledWith(expect.anything(), {
        media: photo,
        familyId: result.family.id,
        memberId: result.member.id,
        now: FIXED_NOW,
      });
    });

    it('rejects a photo from another grant without persisting a family', async () => {
      onboardingMedia.findById.mockResolvedValue({ id: photoId, grantId: 'other-grant' });
      await expect(
        useCase.execute({ ...VALID_COMMAND, creatorPhotoMediaId: photoId }),
      ).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
        fieldErrors: { creatorPhotoMediaId: ['PHOTO_MEDIA_NOT_OWNED'] },
      });
      expect(database.families).toHaveLength(0);
      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('rejects an uploading photo but allows creation when photo is omitted', async () => {
      onboardingMedia.findForGrant.mockResolvedValue({
        id: photoId,
        grantId: 'grant-1',
        purpose: 'PROFILE_PHOTO',
        state: 'UPLOADING',
      });
      await expect(
        useCase.execute({ ...VALID_COMMAND, creatorPhotoMediaId: photoId }),
      ).rejects.toMatchObject({
        fieldErrors: { creatorPhotoMediaId: ['PHOTO_MEDIA_NOT_READY'] },
      });
      await expect(useCase.execute(VALID_COMMAND)).resolves.toMatchObject({
        family: { name: 'Casa Silva' },
      });
    });
    it('creates zero initial members by default and returns an empty list', async () => {
      const result = await useCase.execute(VALID_COMMAND);
      expect(result.initialMembers).toEqual([]);
      expect(database.members).toHaveLength(1);
    });

    it('creates multiple members in request order with server ids and no invite', async () => {
      const result = await useCase.execute({
        ...VALID_COMMAND,
        initialMembers: [
          { name: '  Ana ', role: 'member' },
          { name: 'Leo', role: 'kids' },
        ],
      });
      expect(result.initialMembers).toEqual([
        { id: expect.any(String), name: 'Ana', role: 'member' },
        { id: expect.any(String), name: 'Leo', role: 'kids' },
      ]);
      expect(database.members).toHaveLength(3);
      expect(runner.runs).toBe(1);
    });

    it('rolls back creator and all members when one insert fails', async () => {
      database.failOn = 'insertInitialMember';
      await expect(
        useCase.execute({ ...VALID_COMMAND, initialMembers: [{ name: 'Ana', role: 'member' }] }),
      ).rejects.toBeInstanceOf(DependencyUnavailableError);
      expect(database.families).toHaveLength(0);
      expect(database.members).toHaveLength(0);
      expect(database.sessions).toHaveLength(0);
      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('rejects an invalid member without opening a transaction', async () => {
      await expect(
        useCase.execute({
          ...VALID_COMMAND,
          initialMembers: [
            { name: 'Ana', role: 'member' },
            { name: '', role: 'kids' },
          ],
        }),
      ).rejects.toMatchObject({
        code: 'VALIDATION_FAILED',
        fieldErrors: { 'initialMembers[1].name': ['MEMBER_NAME_REQUIRED'] },
      });
      expect(runner.runs).toBe(0);
    });
    it('creates family, creator administrator, initial cycle and session in one transaction', async () => {
      const result = await useCase.execute(VALID_COMMAND);

      expect(database.families).toHaveLength(1);
      expect(database.members).toHaveLength(1);
      expect(database.cycles).toHaveLength(1);
      expect(database.sessions).toHaveLength(1);
      expect(runner.runs).toBe(1);
      // Uma única transação: todas as escritas receberam o mesmo contexto.
      expect(database.seenContexts.size).toBe(1);

      expect(result.family).toEqual({
        id: database.families[0]?.id,
        name: 'Casa Silva',
        timeZoneId: 'America/Sao_Paulo',
        createdAt: FIXED_NOW.toISOString(),
      });
      expect(result.member).toEqual({
        id: database.members[0]?.id,
        name: 'Maria Silva',
        nickname: 'Mari',
        role: 'administrator',
        isFamilyCreator: true,
      });
      expect(result.session).toMatchObject({
        memberId: result.member.id,
        familyId: result.family.id,
        role: 'administrator',
        isFamilyCreator: true,
      });
    });

    it('opens the initial cycle at creation, ending next Monday in the family time zone', async () => {
      await useCase.execute(VALID_COMMAND);

      expect(database.cycles[0]).toEqual({
        familyId: database.families[0]?.id,
        startsAt: FIXED_NOW,
        endsAt: new Date('2026-10-12T03:00:00.000Z'),
        timeZoneId: 'America/Sao_Paulo',
        referenceWeek: '2026-10-05',
      });
    });

    it('persists only hashes of the session tokens, never the raw values', async () => {
      const result = await useCase.execute(VALID_COMMAND);

      expect(database.sessions[0]?.refreshTokenHash).toBe(sha256(result.session.refreshToken));
      expect(database.accessTokens[0]?.tokenHash).toBe(sha256(result.session.accessToken));
      expect(JSON.stringify([database.sessions, database.accessTokens])).not.toContain(
        result.session.accessToken,
      );
      expect(database.sessions[0]?.installationProofHash).toBe(sha256(INSTALLATION_PROOF));
    });

    it('issues an access token valid for 15 minutes', async () => {
      const result = await useCase.execute(VALID_COMMAND);

      expect(result.session.accessTokenExpiresAt).toBe('2026-10-08T12:15:00.000Z');
    });

    it('consumes the grant and revokes the identity’s other open grants', async () => {
      const sibling = database.addGrant('another-open-grant');

      await useCase.execute(VALID_COMMAND);

      expect(database.grants[0]?.consumedAt).toEqual(FIXED_NOW);
      expect(sibling.revokedAt).toEqual(FIXED_NOW);
    });

    it('locks the creator identity before touching family state', async () => {
      await useCase.execute(VALID_COMMAND);

      expect(database.lockedIdentities).toEqual([IDENTITY_ID]);
    });
  });

  describe('CA-02: default time zone and validation', () => {
    it.each([
      ['omitted', undefined],
      ['null', null],
    ])('uses America/Sao_Paulo when timeZoneId is %s', async (_label, timeZoneId) => {
      const result = await useCase.execute({ ...VALID_COMMAND, timeZoneId });

      expect(result.family.timeZoneId).toBe('America/Sao_Paulo');
    });

    it('stores a time zone chosen explicitly', async () => {
      const result = await useCase.execute({ ...VALID_COMMAND, timeZoneId: 'Europe/Lisbon' });

      expect(result.family.timeZoneId).toBe('Europe/Lisbon');
      expect(database.cycles[0]?.timeZoneId).toBe('Europe/Lisbon');
    });

    it('trims names and stores a missing nickname as null', async () => {
      const result = await useCase.execute({
        ...VALID_COMMAND,
        creatorName: '  Maria Silva ',
        name: ' Casa Silva  ',
        creatorNickname: undefined,
      });

      expect(result.member).toMatchObject({ name: 'Maria Silva', nickname: null });
      expect(result.family.name).toBe('Casa Silva');
    });

    it.each([
      ['empty family name', { name: '' }, { name: ['FAMILY_NAME_REQUIRED'] }],
      ['blank family name', { name: '   ' }, { name: ['FAMILY_NAME_REQUIRED'] }],
      [
        'family name over 60 characters',
        { name: 'a'.repeat(61) },
        { name: ['FAMILY_NAME_INVALID_LENGTH'] },
      ],
      [
        'family name with a control character',
        { name: 'Casa\u0007' },
        { name: ['FAMILY_NAME_INVALID_CONTENT'] },
      ],
      [
        'missing creator name',
        { creatorName: undefined },
        { creatorName: ['MEMBER_NAME_REQUIRED'] },
      ],
      [
        'creator name over 60 characters',
        { creatorName: 'a'.repeat(61) },
        { creatorName: ['MEMBER_NAME_INVALID_LENGTH'] },
      ],
      [
        'creator name with a control character',
        { creatorName: 'Ma\u0000ria' },
        { creatorName: ['MEMBER_NAME_INVALID_CONTENT'] },
      ],
      [
        'nickname over 20 non-space characters',
        { creatorNickname: 'a'.repeat(21) },
        { creatorNickname: ['NICKNAME_INVALID_LENGTH'] },
      ],
      [
        'unknown time zone',
        { timeZoneId: 'Mars/Olympus' },
        { timeZoneId: ['TIME_ZONE_ID_INVALID'] },
      ],
      ['non-string time zone', { timeZoneId: 3 }, { timeZoneId: ['TIME_ZONE_ID_INVALID'] }],
    ])('rejects %s with 422 and the field error code', async (_label, override, fieldErrors) => {
      const error = await useCase.execute({ ...VALID_COMMAND, ...override }).catch((e) => e);

      expect(error).toBeInstanceOf(ValidationError);
      expect(error).toMatchObject({
        statusCode: 422,
        code: 'VALIDATION_FAILED',
        fieldErrors,
      });
    });

    it('reports every invalid field at once', async () => {
      const error = await useCase
        .execute({ ...VALID_COMMAND, name: '', creatorName: '', timeZoneId: 'nope' })
        .catch((e) => e);

      expect(Object.keys(error.fieldErrors).sort()).toEqual(['creatorName', 'name', 'timeZoneId']);
    });

    it('does not consume the grant when validation fails, so the user can retry', async () => {
      await expect(useCase.execute({ ...VALID_COMMAND, name: '' })).rejects.toBeInstanceOf(
        ValidationError,
      );

      expect(database.grants[0]?.consumedAt).toBeUndefined();
      expect(runner.runs).toBe(0);
    });
  });

  describe('CA-04: grant and client input do not authorize misuse', () => {
    const expectRejectedWithoutPersisting = async (command: CreateFamilyCommand) => {
      const error = await useCase.execute(command).catch((e) => e);

      expect(error).toBeInstanceOf(CreationGrantInvalidError);
      expect(error).toMatchObject({ statusCode: 401, code: 'CREATION_GRANT_INVALID' });
      expect(database.families).toHaveLength(0);
      expect(database.members).toHaveLength(0);
      expect(database.cycles).toHaveLength(0);
      expect(database.sessions).toHaveLength(0);
    };

    it.each([
      ['missing', undefined],
      ['empty', ''],
      ['not a string', 123],
      ['unknown', 'a-grant-nobody-issued'],
    ])('rejects a %s grant', async (_label, creationGrant) => {
      await expectRejectedWithoutPersisting({ ...VALID_COMMAND, creationGrant });
    });

    it('rejects an expired grant', async () => {
      database.grants[0]!.expiresAt = new Date(FIXED_NOW.getTime() - 1);

      await expectRejectedWithoutPersisting(VALID_COMMAND);
    });

    it('rejects a revoked grant', async () => {
      database.grants[0]!.revokedAt = new Date(FIXED_NOW.getTime() - 1000);

      await expectRejectedWithoutPersisting(VALID_COMMAND);
    });

    it('rejects a grant presented from another installation without burning it', async () => {
      await expectRejectedWithoutPersisting({
        ...VALID_COMMAND,
        installationProof: 'proof-from-a-different-device',
      });

      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('rejects a usable grant when the identity already has a family', async () => {
      database.members.push({
        id: 'existing-member',
        familyId: 'existing-family',
        creatorIdentityId: IDENTITY_ID,
        name: 'Existing',
        nickname: null,
      });

      const error = await useCase.execute(VALID_COMMAND).catch((e) => e);

      expect(error).toBeInstanceOf(CreationGrantInvalidError);
      expect(database.families).toHaveLength(0);
      // A recusa desfaz o consumo: nada ficou gravado pela transação.
      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('takes family and role only from the grant, never from the command', async () => {
      const result = await useCase.execute({
        ...VALID_COMMAND,
        // Campos que o schema HTTP recusa; se chegassem aqui, seriam ignorados.
        familyId: 'victim-family',
        role: 'member',
        isFamilyCreator: false,
      } as CreateFamilyCommand);

      expect(result.session.familyId).toBe(database.families[0]?.id);
      expect(result.session.familyId).not.toBe('victim-family');
      expect(result.member.role).toBe('administrator');
      expect(result.member.isFamilyCreator).toBe(true);
    });
  });

  describe('CA-03: a single association per identity', () => {
    it('refuses a second creation with the same grant and keeps one family', async () => {
      await useCase.execute(VALID_COMMAND);

      await expect(useCase.execute(VALID_COMMAND)).rejects.toBeInstanceOf(
        CreationGrantInvalidError,
      );
      expect(database.families).toHaveLength(1);
      expect(database.members).toHaveLength(1);
    });

    it('refuses a second creation with another still-valid grant of the same identity', async () => {
      database.addGrant('second-grant');
      await useCase.execute(VALID_COMMAND);

      await expect(
        useCase.execute({ ...VALID_COMMAND, creationGrant: 'second-grant' }),
      ).rejects.toBeInstanceOf(CreationGrantInvalidError);
      expect(database.families).toHaveLength(1);
    });
  });

  describe('CA-09: persistence failure and uncertain outcome', () => {
    it('answers 503 and leaves no partial family when a write fails', async () => {
      database.failOn = 'insertFamily';

      const error = await useCase.execute(VALID_COMMAND).catch((e) => e);

      expect(error).toBeInstanceOf(DependencyUnavailableError);
      expect(error).toMatchObject({ statusCode: 503, code: 'DEPENDENCY_UNAVAILABLE' });
      expect(database.families).toHaveLength(0);
      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('rolls back the family when the session cannot be issued', async () => {
      database.failOn = 'insertSession';

      await expect(useCase.execute(VALID_COMMAND)).rejects.toBeInstanceOf(
        DependencyUnavailableError,
      );

      expect(database.families).toHaveLength(0);
      expect(database.members).toHaveLength(0);
      expect(database.cycles).toHaveLength(0);
      expect(database.grants[0]?.consumedAt).toBeUndefined();
    });

    it('does not claim the write was undone in the error message', async () => {
      database.failOn = 'insertFamily';

      const error = await useCase.execute(VALID_COMMAND).catch((e) => e);

      expect(error.message).toMatch(/uncertain/i);
      expect(error.message).not.toMatch(/rolled back|reverted|undone/i);
    });
  });

  describe('observability (RNF08)', () => {
    it('logs family_created with the family and time zone only', async () => {
      const result = await useCase.execute(VALID_COMMAND);

      expect(logCalls).toContainEqual([
        'info',
        'family_created',
        { familyId: result.family.id, timeZoneId: 'America/Sao_Paulo' },
      ]);
    });

    it('logs family_creation_rejected with a technical reason and no secrets or names', async () => {
      await useCase.execute({ ...VALID_COMMAND, creationGrant: 'unknown' }).catch(() => undefined);
      await useCase.execute({ ...VALID_COMMAND, name: '' }).catch(() => undefined);

      expect(logCalls).toContainEqual([
        'warn',
        'family_creation_rejected',
        { reason: 'CREATION_GRANT_INVALID' },
      ]);
      expect(logCalls).toContainEqual([
        'warn',
        'family_creation_rejected',
        { reason: 'VALIDATION_FAILED' },
      ]);

      const serialized = JSON.stringify(logCalls);
      for (const secret of [GRANT, INSTALLATION_PROOF, 'Maria Silva', 'Casa Silva', 'unknown']) {
        expect(serialized).not.toContain(secret);
      }
    });

    it('never logs the issued session tokens', async () => {
      const result = await useCase.execute(VALID_COMMAND);
      const serialized = JSON.stringify(logCalls);

      expect(serialized).not.toContain(result.session.accessToken);
      expect(serialized).not.toContain(result.session.refreshToken);
    });
  });
});
