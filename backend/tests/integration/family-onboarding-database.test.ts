/**
 * Onboarding do Criador contra PostgreSQL real, após as migrations (SPEC-002
 * Fase 1: CA-01, CA-03, CA-04, CA-09 e CA-10).
 *
 * Prova o que um dublê em memória não prova: atomicidade do BEGIN/COMMIT,
 * serialização de criações concorrentes, consumo único do grant, FKs compostas
 * entre famílias e ausência de privilégio público. Desligado por padrão; use
 * `RUN_INTEGRATION_TESTS=1`.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { AuthenticateSessionUseCase } from '../../src/modules/access/application/authenticate-session-use-case.js';
import { SessionIssuer } from '../../src/modules/access/application/session-issuer.js';
import { CryptoTokenService } from '../../src/modules/access/infrastructure/crypto-token-service.js';
import { PostgresAccessRepository } from '../../src/modules/access/infrastructure/postgres-access-repository.js';
import { PostgresSessionLookup } from '../../src/modules/access/infrastructure/postgres-session-lookup.js';
import { CreateFamilyUseCase } from '../../src/modules/family/application/create-family-use-case.js';
import type { CreateFamilyCommand } from '../../src/modules/family/application/create-family-dto.js';
import { PostgresFamilyCreationRepository } from '../../src/modules/family/infrastructure/postgres-family-creation-repository.js';
import {
  GetFamilyUseCase,
  UpdateFamilyUseCase,
} from '../../src/modules/family/application/family-profile-use-cases.js';
import { PostgresFamilyProfileRepository } from '../../src/modules/family/infrastructure/postgres-family-profile-repository.js';
import { PostgresOnboardingMediaRepository } from '../../src/modules/media/infrastructure/postgres-onboarding-media-repository.js';
import type { ObjectStoragePort } from '../../src/modules/media/application/media-ports.js';
import { UploadOnboardingMediaUseCase } from '../../src/modules/media/application/upload-onboarding-media-use-case.js';
import { CleanOrphanOnboardingMedia } from '../../src/modules/media/application/clean-orphan-onboarding-media.js';
import { UploadMediaUseCase } from '../../src/modules/media/application/upload-media-use-case.js';
import {
  PhotoMediaNotOwnedError,
  PhotoMediaNotReadyError,
} from '../../src/modules/media/domain/media-errors.js';
import { PostgresMediaRepository } from '../../src/modules/media/infrastructure/postgres-media-repository.js';
import { SharpImageProcessor } from '../../src/modules/media/infrastructure/sharp-image-processor.js';
import { UpdateOwnProfileUseCase } from '../../src/modules/profile/application/update-own-profile-use-case.js';
import { PostgresProfileRepository } from '../../src/modules/profile/infrastructure/postgres-profile-repository.js';
import { SystemClock } from '../../src/shared/application/clock.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';
import { createRecordingLogger } from '../support/fake-logger.js';

const INTEGRATION_TIMEOUT_MS = 60_000;

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family onboarding persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    const accessRepository = new PostgresAccessRepository();
    const familyRepository = new PostgresFamilyCreationRepository();
    const mediaRepository = new PostgresMediaRepository();
    const crypto = new CryptoTokenService('integration-test-session-secret-min-32-chars!');
    const clock = new SystemClock();
    const { logger } = createRecordingLogger();

    const createdIdentityIds: string[] = [];

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }

      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      // Higiene: remover o que o teste criou. Famílias saem em cascata (membros,
      // sessões, ciclos, mídia); identidades e grants em seguida.
      if (container !== undefined) {
        const pool = container.dbPool;
        for (const identityId of createdIdentityIds) {
          await pool.query(
            `delete from app.onboarding_media where grant_id in
               (select id from app.family_creation_grants where creator_identity_id = $1)`,
            [identityId],
          );
          await pool.query(
            `delete from app.families where id in
               (select family_id from app.members where creator_identity_id = $1)`,
            [identityId],
          );
          await pool.query(`delete from app.creator_identities where id = $1`, [identityId]);
        }
      }
      await container?.dispose();
    });

    const createFamilyUseCase = (
      repository: PostgresFamilyCreationRepository = familyRepository,
    ): CreateFamilyUseCase =>
      new CreateFamilyUseCase({
        repository,
        onboardingMedia: new PostgresOnboardingMediaRepository(),
        sessionIssuer: new SessionIssuer({ repository: accessRepository, crypto, logger }),
        crypto,
        transactionRunner: container.transactionRunner,
        clock,
        logger,
      });

    /** Identidade Apple nova com N grants abertos, como o login da SPEC-001 deixa. */
    async function seedIdentityWithGrants(
      grantCount = 1,
      installationProof = 'installation-proof',
    ): Promise<{ identityId: string; grants: string[]; installationProof: string }> {
      const subject = `001234.family.${randomUUID()}`;
      const identityId = randomUUID();
      const grants: string[] = [];

      await container.transactionRunner.run(async (tx) => {
        await accessRepository.insertCreatorIdentity(tx, {
          identityId,
          appleSubjectHash: crypto.hashAppleSubject(subject),
          appleSubjectEncrypted: crypto.encryptAppleSubject(subject),
        });

        for (let index = 0; index < grantCount; index += 1) {
          const grant = crypto.generateOpaqueToken();
          grants.push(grant);
          await accessRepository.insertCreationGrant(tx, {
            grantId: randomUUID(),
            creatorIdentityId: identityId,
            grantTokenHash: crypto.hashToken(grant),
            installationProofHash: crypto.hashToken(installationProof),
            expiresAt: new Date(Date.now() + 10 * 60 * 1000),
          });
        }
      });

      createdIdentityIds.push(identityId);
      return { identityId, grants, installationProof };
    }

    const commandFor = (
      seed: { grants: string[]; installationProof: string },
      overrides: Partial<CreateFamilyCommand> = {},
    ): CreateFamilyCommand => ({
      creationGrant: seed.grants[0],
      creatorName: 'Maria Silva',
      creatorNickname: 'Mari',
      name: 'Casa Silva',
      timeZoneId: 'America/Sao_Paulo',
      installationProof: seed.installationProof,
      ...overrides,
    });

    const count = async (sql: string, params: unknown[]): Promise<number> => {
      const result = await container.dbPool.query<{ total: string }>(sql, params);
      return Number(result.rows[0]?.total);
    };

    const familiesOf = (identityId: string) =>
      count(`select count(*) as total from app.members where creator_identity_id = $1`, [
        identityId,
      ]);

    describe('CA-01: atomic creation', () => {
      it('persists multiple initial members without creating invites', async () => {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(
          commandFor(seed, {
            initialMembers: [
              { name: 'Ana', role: 'member' },
              { name: 'Leo', role: 'kids' },
            ],
          }),
        );
        expect(result.initialMembers).toEqual([
          { id: expect.any(String), name: 'Ana', role: 'member' },
          { id: expect.any(String), name: 'Leo', role: 'kids' },
        ]);
        expect(
          await count(`select count(*) as total from app.members where family_id = $1`, [
            result.family.id,
          ]),
        ).toBe(3);
        expect(
          await count(`select count(*) as total from app.member_invites where family_id = $1`, [
            result.family.id,
          ]),
        ).toBe(0);
      });

      it('moves a READY photo to the creator only on confirmed creation', async () => {
        const seed = await seedIdentityWithGrants();
        const photoId = randomUUID();
        await container.dbPool.query(
          `insert into app.onboarding_media (id, grant_id, object_key, purpose, state, size_bytes, content_type)
           values ($1, (select id from app.family_creation_grants where grant_token_hash = $2), $3, 'PROFILE_PHOTO', 'READY', 4, 'image/jpeg')`,
          [photoId, crypto.hashToken(seed.grants[0]!), `test/onboarding/${photoId}.jpg`],
        );
        const result = await createFamilyUseCase().execute(
          commandFor(seed, { creatorPhotoMediaId: photoId }),
        );
        const member = await container.dbPool.query<{ photo_media_id: string }>(
          `select photo_media_id from app.members where id = $1`,
          [result.member.id],
        );
        expect(member.rows[0]?.photo_media_id).toBe(photoId);
        expect(
          await count(`select count(*) as total from app.onboarding_media where id = $1`, [
            photoId,
          ]),
        ).toBe(0);
        expect(
          await count(
            `select count(*) as total from app.media_assets where id = $1 and family_id = $2 and owner_member_id = $3`,
            [photoId, result.family.id, result.member.id],
          ),
        ).toBe(1);
      });

      it('rolls back all rows for an invalid member before writing', async () => {
        const seed = await seedIdentityWithGrants();
        await expect(
          createFamilyUseCase().execute(
            commandFor(seed, {
              initialMembers: [
                { name: 'Ana', role: 'member' },
                { name: '', role: 'kids' },
              ],
            }),
          ),
        ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
        expect(await familiesOf(seed.identityId)).toBe(0);
      });
      it('persists family, creator, initial cycle and session together', async () => {
        const seed = await seedIdentityWithGrants();

        const result = await createFamilyUseCase().execute(commandFor(seed));

        const family = await container.dbPool.query(
          `select name, timezone from app.families where id = $1`,
          [result.family.id],
        );
        expect(family.rows[0]).toEqual({ name: 'Casa Silva', timezone: 'America/Sao_Paulo' });

        const member = await container.dbPool.query(
          `select role, is_family_creator, display_name, nickname, creator_identity_id, photo_media_id
             from app.members where id = $1 and family_id = $2`,
          [result.member.id, result.family.id],
        );
        expect(member.rows[0]).toEqual({
          role: 'administrator',
          is_family_creator: true,
          display_name: 'Maria Silva',
          nickname: 'Mari',
          creator_identity_id: seed.identityId,
          photo_media_id: null,
        });

        const cycle = await container.dbPool.query<{
          starts_at: Date;
          ends_at: Date;
          time_zone: string;
          reference_week: string;
        }>(
          `select starts_at, ends_at, time_zone, to_char(reference_week, 'YYYY-MM-DD') as reference_week
             from app.weekly_cycles where family_id = $1`,
          [result.family.id],
        );
        expect(cycle.rows).toHaveLength(1);
        expect(cycle.rows[0]?.time_zone).toBe('America/Sao_Paulo');
        expect(cycle.rows[0]!.ends_at.getTime()).toBeGreaterThan(
          cycle.rows[0]!.starts_at.getTime(),
        );

        const session = await container.dbPool.query(
          `select member_id, family_id, refresh_token_hash
             from app.sessions where id = $1 and revoked_at is null`,
          [result.session.sessionId],
        );
        expect(session.rows[0]).toMatchObject({
          member_id: result.member.id,
          family_id: result.family.id,
          refresh_token_hash: crypto.hashToken(result.session.refreshToken),
        });

        const grant = await container.dbPool.query(
          `select consumed_at from app.family_creation_grants where grant_token_hash = $1`,
          [crypto.hashToken(seed.grants[0]!)],
        );
        expect(grant.rows[0]?.consumed_at).not.toBeNull();
      });

      it('stores the cycle end on a Monday 00:00 in the family time zone', async () => {
        const seed = await seedIdentityWithGrants();

        const result = await createFamilyUseCase().execute(
          commandFor(seed, { timeZoneId: 'Asia/Tokyo' }),
        );

        const cycle = await container.dbPool.query<{ local_end: string; dow: number }>(
          `select to_char(ends_at at time zone 'Asia/Tokyo', 'YYYY-MM-DD HH24:MI:SS') as local_end,
                  extract(isodow from ends_at at time zone 'Asia/Tokyo')::int as dow
             from app.weekly_cycles where family_id = $1`,
          [result.family.id],
        );
        expect(cycle.rows[0]?.dow).toBe(1);
        expect(cycle.rows[0]?.local_end.endsWith('00:00:00')).toBe(true);
      });
    });

    describe('CA-09: no partial family when a step fails', () => {
      it('rolls back family, creator and grant consumption', async () => {
        const seed = await seedIdentityWithGrants();

        class FailingCycleRepository extends PostgresFamilyCreationRepository {
          public override async insertWeeklyCycle(): Promise<void> {
            throw new Error('simulated failure after the family rows were written');
          }
        }

        await expect(
          createFamilyUseCase(new FailingCycleRepository()).execute(commandFor(seed)),
        ).rejects.toMatchObject({ statusCode: 503, code: 'DEPENDENCY_UNAVAILABLE' });

        expect(await familiesOf(seed.identityId)).toBe(0);
        const grant = await container.dbPool.query(
          `select consumed_at from app.family_creation_grants where grant_token_hash = $1`,
          [crypto.hashToken(seed.grants[0]!)],
        );
        // Grant intacto: a pessoa pode tentar de novo dentro dos 10 minutos.
        expect(grant.rows[0]?.consumed_at).toBeNull();

        // E a nova tentativa, sem a falha, funciona.
        await expect(createFamilyUseCase().execute(commandFor(seed))).resolves.toBeDefined();
      });
    });

    describe('CA-12: existing family access', () => {
      it('allows adult reading, restricts editing to the administrator and isolates families', async () => {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(
          commandFor(seed, {
            initialMembers: [
              { name: 'Adulto', role: 'member' },
              { name: 'Crianca', role: 'kids' },
            ],
          }),
        );
        const repo = new PostgresFamilyProfileRepository();
        const get = new GetFamilyUseCase({
          repository: repo,
          transactionRunner: container.transactionRunner,
        });
        const update = new UpdateFamilyUseCase({
          repository: repo,
          transactionRunner: container.transactionRunner,
          clock,
        });
        const creator = {
          sessionId: result.session.sessionId,
          familyId: result.family.id,
          memberId: result.member.id,
          role: 'administrator' as const,
          isFamilyCreator: true,
        };
        const adult = {
          ...creator,
          memberId: result.initialMembers[0]!.id,
          role: 'member' as const,
          isFamilyCreator: false,
        };
        const kid = {
          ...creator,
          memberId: result.initialMembers[1]!.id,
          role: 'kids' as const,
          isFamilyCreator: false,
        };

        await expect(get.execute(adult)).resolves.toEqual({
          id: result.family.id,
          name: 'Casa Silva',
          timeZoneId: 'America/Sao_Paulo',
        });
        await expect(get.execute(kid)).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
        await expect(update.execute(adult, 'Outra Casa')).rejects.toMatchObject({
          code: 'ACTION_NOT_ALLOWED',
        });
        await expect(update.execute(creator, 'Nova Casa')).resolves.toMatchObject({
          name: 'Nova Casa',
        });
        await expect(get.execute({ ...adult, familyId: randomUUID() })).rejects.toMatchObject({
          code: 'RESOURCE_NOT_FOUND',
        });
      });
    });

    describe('CA-03: a single association under concurrency', () => {
      it('creates exactly one family when the same grant is used twice at once', async () => {
        const seed = await seedIdentityWithGrants();

        const outcomes = await Promise.allSettled([
          createFamilyUseCase().execute(commandFor(seed)),
          createFamilyUseCase().execute(commandFor(seed)),
        ]);

        expect(outcomes.filter((o) => o.status === 'fulfilled')).toHaveLength(1);
        const rejected = outcomes.find((o) => o.status === 'rejected');
        expect(rejected).toMatchObject({
          reason: { statusCode: 401, code: 'CREATION_GRANT_INVALID' },
        });
        expect(await familiesOf(seed.identityId)).toBe(1);
      });

      it('creates exactly one family when two different grants of the identity race', async () => {
        const seed = await seedIdentityWithGrants(2);

        const outcomes = await Promise.allSettled([
          createFamilyUseCase().execute(commandFor(seed, { creationGrant: seed.grants[0] })),
          createFamilyUseCase().execute(commandFor(seed, { creationGrant: seed.grants[1] })),
        ]);

        expect(outcomes.filter((o) => o.status === 'fulfilled')).toHaveLength(1);
        expect(await familiesOf(seed.identityId)).toBe(1);
        expect(
          await count(
            `select count(*) as total from app.sessions s
               join app.members m on m.id = s.member_id
              where m.creator_identity_id = $1`,
            [seed.identityId],
          ),
        ).toBe(1);
      });

      it('lets a later authentication discover the existing family instead of duplicating it', async () => {
        const seed = await seedIdentityWithGrants(2);
        await createFamilyUseCase().execute(commandFor(seed, { creationGrant: seed.grants[0] }));

        await expect(
          createFamilyUseCase().execute(commandFor(seed, { creationGrant: seed.grants[1] })),
        ).rejects.toMatchObject({ code: 'CREATION_GRANT_INVALID' });

        const membership = await container.transactionRunner.run((tx) =>
          accessRepository.findCreatorMembership(tx, seed.identityId),
        );
        expect(membership).toMatchObject({ role: 'administrator', isFamilyCreator: true });
      });
    });

    describe('CA-04: grant restrictions', () => {
      it('rejects an expired grant', async () => {
        const seed = await seedIdentityWithGrants();
        await container.dbPool.query(
          `update app.family_creation_grants set expires_at = now() - interval '1 second'
            where grant_token_hash = $1`,
          [crypto.hashToken(seed.grants[0]!)],
        );

        await expect(createFamilyUseCase().execute(commandFor(seed))).rejects.toMatchObject({
          code: 'CREATION_GRANT_INVALID',
        });
        expect(await familiesOf(seed.identityId)).toBe(0);
      });

      it('rejects a grant from another installation and keeps it usable by the owner', async () => {
        const seed = await seedIdentityWithGrants();

        await expect(
          createFamilyUseCase().execute(
            commandFor(seed, { installationProof: 'another-device-proof' }),
          ),
        ).rejects.toMatchObject({ code: 'CREATION_GRANT_INVALID' });

        await expect(createFamilyUseCase().execute(commandFor(seed))).resolves.toBeDefined();
      });
    });

    describe('session authentication', () => {
      const authenticate = () =>
        new AuthenticateSessionUseCase({
          sessionLookup: new PostgresSessionLookup(container.dbPool),
          crypto,
          clock,
        });

      it('resolves the actor from the access token issued at creation', async () => {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(commandFor(seed));

        const actor = await authenticate().execute(result.session.accessToken);

        expect(actor).toEqual({
          sessionId: result.session.sessionId,
          familyId: result.family.id,
          memberId: result.member.id,
          role: 'administrator',
          isFamilyCreator: true,
        });
      });

      it('rejects an expired access token', async () => {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(commandFor(seed));
        await container.dbPool.query(
          `update app.session_access_tokens set expires_at = now() - interval '1 second'
            where token_hash = $1`,
          [crypto.hashToken(result.session.accessToken)],
        );

        await expect(authenticate().execute(result.session.accessToken)).rejects.toMatchObject({
          code: 'ACCESS_TOKEN_INVALID',
        });
      });

      it('rejects a token whose session was revoked', async () => {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(commandFor(seed));
        await container.dbPool.query(`update app.sessions set revoked_at = now() where id = $1`, [
          result.session.sessionId,
        ]);

        await expect(authenticate().execute(result.session.accessToken)).rejects.toMatchObject({
          code: 'ACCESS_TOKEN_INVALID',
        });
      });

      it('rejects an unknown token', async () => {
        await expect(authenticate().execute('not-a-token')).rejects.toMatchObject({
          code: 'ACCESS_TOKEN_INVALID',
        });
      });

      it('never resolves a family other than the one the session belongs to', async () => {
        const first = await createFamilyUseCase().execute(
          commandFor(await seedIdentityWithGrants()),
        );
        const second = await createFamilyUseCase().execute(
          commandFor(await seedIdentityWithGrants(), { name: 'Casa Souza' }),
        );

        const actor = await authenticate().execute(first.session.accessToken);

        expect(actor.familyId).toBe(first.family.id);
        expect(actor.familyId).not.toBe(second.family.id);
      });
    });

    describe('CA-10: optional initial photo', () => {
      const onboardingRepository = new PostgresOnboardingMediaRepository();

      it('uploads before family creation and links only in the creation commit', async () => {
        const seed = await seedIdentityWithGrants();
        const objects = new Map<string, Buffer>();
        const storage = {
          async put({ key, body }: { key: string; body: Buffer }) {
            objects.set(key, body);
          },
          async delete(key: string) {
            objects.delete(key);
          },
        };
        const upload = new UploadOnboardingMediaUseCase({
          repository: onboardingRepository,
          storage,
          imageProcessor: new SharpImageProcessor(),
          crypto,
          transactionRunner: container.transactionRunner,
          clock,
          logger,
          keyPrefix: 'integration',
        });
        const content = await sharp({
          create: { width: 8, height: 8, channels: 3, background: '#0a84ff' },
        })
          .png()
          .toBuffer();
        const media = await upload.execute({
          creationGrant: seed.grants[0],
          installationProof: seed.installationProof,
          purpose: 'profilePhoto',
          content,
        });
        expect(await familiesOf(seed.identityId)).toBe(0);
        expect(
          await count(
            `select count(*) as total from app.onboarding_media where id = $1 and state = 'READY'`,
            [media.mediaId],
          ),
        ).toBe(1);
        const created = await createFamilyUseCase().execute(
          commandFor(seed, { creatorPhotoMediaId: media.mediaId }),
        );
        expect(
          await count(`select count(*) as total from app.onboarding_media where id = $1`, [
            media.mediaId,
          ]),
        ).toBe(0);
        expect(
          await count(
            `select count(*) as total from app.media_assets where id = $1 and owner_member_id = $2`,
            [media.mediaId, created.member.id],
          ),
        ).toBe(1);
        expect(objects.size).toBe(1);
      });

      it('rejects a photo prepared for another grant and leaves both identities unassociated', async () => {
        const owner = await seedIdentityWithGrants();
        const other = await seedIdentityWithGrants();
        const photoId = randomUUID();
        await container.dbPool.query(
          `insert into app.onboarding_media (id, grant_id, object_key, purpose, state, size_bytes, content_type)
           values ($1, (select id from app.family_creation_grants where grant_token_hash = $2), $3, 'PROFILE_PHOTO', 'READY', 4, 'image/jpeg')`,
          [photoId, crypto.hashToken(owner.grants[0]!), `integration/onboarding/${photoId}.jpg`],
        );
        await expect(
          createFamilyUseCase().execute(commandFor(other, { creatorPhotoMediaId: photoId })),
        ).rejects.toMatchObject({
          fieldErrors: { creatorPhotoMediaId: ['PHOTO_MEDIA_NOT_OWNED'] },
        });
        expect(await familiesOf(owner.identityId)).toBe(0);
        expect(await familiesOf(other.identityId)).toBe(0);
      });

      it('cleans an abandoned reservation after 24 hours', async () => {
        const seed = await seedIdentityWithGrants();
        const id = randomUUID();
        await container.dbPool.query(
          `insert into app.onboarding_media (id, grant_id, object_key, purpose, state, created_at)
           values ($1, (select id from app.family_creation_grants where grant_token_hash = $2), $3, 'PROFILE_PHOTO', 'FAILED', now() - interval '25 hours')`,
          [id, crypto.hashToken(seed.grants[0]!), `integration/onboarding/${id}.jpg`],
        );
        const deleted: string[] = [];
        const cleaner = new CleanOrphanOnboardingMedia({
          repository: onboardingRepository,
          storage: {
            async put() {},
            async get() {
              return undefined;
            },
            async delete(key) {
              deleted.push(key);
            },
          },
          transactionRunner: container.transactionRunner,
          clock,
          logger,
        });
        await cleaner.run();
        expect(deleted).toContain(`integration/onboarding/${id}.jpg`);
        expect(
          await count(`select count(*) as total from app.onboarding_media where id = $1`, [id]),
        ).toBe(0);
      });

      const profileUseCase = () =>
        new UpdateOwnProfileUseCase({
          profileRepository: new PostgresProfileRepository(),
          mediaRepository,
          transactionRunner: container.transactionRunner,
          clock,
        });

      const uploadUseCase = (storage: ObjectStoragePort) =>
        new UploadMediaUseCase({
          repository: mediaRepository,
          storage,
          imageProcessor: new SharpImageProcessor(),
          crypto,
          transactionRunner: container.transactionRunner,
          logger,
          keyPrefix: 'integration',
        });

      const memoryStorage = () => {
        const objects = new Map<string, Buffer>();
        const storage: ObjectStoragePort = {
          async put({ key, body }) {
            objects.set(key, body);
          },
        };
        return { storage, objects };
      };

      const png = () =>
        sharp({ create: { width: 64, height: 64, channels: 3, background: '#0a84ff' } })
          .png()
          .toBuffer();

      async function creator() {
        const seed = await seedIdentityWithGrants();
        const result = await createFamilyUseCase().execute(commandFor(seed));
        return {
          result,
          actor: {
            sessionId: result.session.sessionId,
            familyId: result.family.id,
            memberId: result.member.id,
            role: 'administrator' as const,
            isFamilyCreator: true,
          },
        };
      }

      it('uploads a photo and links it to the creator; the family exists regardless', async () => {
        const { result, actor } = await creator();
        const { storage, objects } = memoryStorage();

        const upload = await uploadUseCase(storage).execute({
          actor,
          purpose: 'profilePhoto',
          content: await png(),
        });
        await profileUseCase().execute({ actor, photoMediaId: upload.mediaId });

        expect(upload.state).toBe('READY');
        expect(objects.size).toBe(1);
        const [key] = [...objects.keys()];
        expect(key).toBe(
          `integration/families/${result.family.id}/profile-photos/${upload.mediaId}.jpg`,
        );

        const member = await container.dbPool.query(
          `select photo_media_id from app.members where id = $1`,
          [result.member.id],
        );
        expect(member.rows[0]?.photo_media_id).toBe(upload.mediaId);
        const media = await container.dbPool.query(
          `select state, purpose, content_type, linked_at from app.media_assets where id = $1`,
          [upload.mediaId],
        );
        expect(media.rows[0]).toMatchObject({
          state: 'READY',
          purpose: 'PROFILE_PHOTO',
          content_type: 'image/jpeg',
        });
        expect(media.rows[0]?.linked_at).not.toBeNull();
      });

      it('keeps family and session when the object storage fails, and marks the media FAILED', async () => {
        const { result, actor } = await creator();
        const failing: ObjectStoragePort = {
          async put() {
            throw new Error('r2 down');
          },
        };

        await expect(
          uploadUseCase(failing).execute({
            actor,
            purpose: 'profilePhoto',
            content: await png(),
          }),
        ).rejects.toMatchObject({ statusCode: 503, code: 'DEPENDENCY_UNAVAILABLE' });

        const media = await container.dbPool.query(
          `select state from app.media_assets where owner_member_id = $1`,
          [result.member.id],
        );
        expect(media.rows).toEqual([{ state: 'FAILED' }]);
        expect(
          await count(`select count(*) as total from app.families where id = $1`, [
            result.family.id,
          ]),
        ).toBe(1);
        // A mídia que falhou não pode ser vinculada.
        await expect(
          profileUseCase().execute({
            actor,
            photoMediaId: (
              await container.dbPool.query<{ id: string }>(
                `select id from app.media_assets where owner_member_id = $1`,
                [result.member.id],
              )
            ).rows[0]!.id,
          }),
        ).rejects.toBeInstanceOf(PhotoMediaNotReadyError);
      });

      it('refuses media of another family with 404 and never links it', async () => {
        const mine = await creator();
        const theirs = await creator();
        const { storage } = memoryStorage();
        const foreign = await uploadUseCase(storage).execute({
          actor: theirs.actor,
          purpose: 'profilePhoto',
          content: await png(),
        });

        await expect(
          profileUseCase().execute({ actor: mine.actor, photoMediaId: foreign.mediaId }),
        ).rejects.toBeInstanceOf(NotFoundError);

        const member = await container.dbPool.query(
          `select photo_media_id from app.members where id = $1`,
          [mine.result.member.id],
        );
        expect(member.rows[0]?.photo_media_id).toBeNull();
      });

      it('refuses media of another member of the same family with PHOTO_MEDIA_NOT_OWNED', async () => {
        const { result, actor } = await creator();
        const { storage } = memoryStorage();

        // Segundo membro da mesma família, inserido direto: a criação de membros
        // pertence à SPEC-003.
        const otherMemberId = randomUUID();
        await container.dbPool.query(
          `insert into app.members (id, family_id, role, display_name)
           values ($1, $2, 'member', 'Outro')`,
          [otherMemberId, result.family.id],
        );
        const othersMedia = await uploadUseCase(storage).execute({
          actor: { ...actor, memberId: otherMemberId, isFamilyCreator: false },
          purpose: 'profilePhoto',
          content: await png(),
        });

        await expect(
          profileUseCase().execute({ actor, photoMediaId: othersMedia.mediaId }),
        ).rejects.toBeInstanceOf(PhotoMediaNotOwnedError);
      });

      it('removes the photo with null', async () => {
        const { result, actor } = await creator();
        const { storage } = memoryStorage();
        const upload = await uploadUseCase(storage).execute({
          actor,
          purpose: 'profilePhoto',
          content: await png(),
        });
        await profileUseCase().execute({ actor, photoMediaId: upload.mediaId });

        await profileUseCase().execute({ actor, photoMediaId: null });

        const member = await container.dbPool.query(
          `select photo_media_id from app.members where id = $1`,
          [result.member.id],
        );
        expect(member.rows[0]?.photo_media_id).toBeNull();
      });

      it('lets the database refuse a photo from another family even if the app is bypassed', async () => {
        const mine = await creator();
        const theirs = await creator();
        const { storage } = memoryStorage();
        const foreign = await uploadUseCase(storage).execute({
          actor: theirs.actor,
          purpose: 'profilePhoto',
          content: await png(),
        });

        await expect(
          container.dbPool.query(`update app.members set photo_media_id = $1 where id = $2`, [
            foreign.mediaId,
            mine.result.member.id,
          ]),
        ).rejects.toThrow(/members_photo_media_fk/);
      });
    });

    describe('database invariants of migration 0004', () => {
      it('grants no privilege on the new tables to anon or authenticated (BA-19)', async () => {
        const result = await container.dbPool.query<{ grantee: string; table_name: string }>(
          `select grantee, table_name
             from information_schema.role_table_grants
            where table_schema = 'app'
              and table_name in ('media_assets', 'weekly_cycles')
              and grantee in ('anon', 'authenticated')`,
        );

        expect(result.rows).toEqual([]);
      });

      it('rejects a cycle that ends before it starts', async () => {
        const result = await createFamilyUseCase().execute(
          commandFor(await seedIdentityWithGrants()),
        );

        await expect(
          container.dbPool.query(
            `insert into app.weekly_cycles (id, family_id, starts_at, ends_at, time_zone, reference_week)
             values ($1, $2, now(), now() - interval '1 day', 'UTC', current_date)`,
            [randomUUID(), result.family.id],
          ),
        ).rejects.toThrow();
      });

      it('rejects a second cycle with the same start for the family', async () => {
        const result = await createFamilyUseCase().execute(
          commandFor(await seedIdentityWithGrants()),
        );
        const existing = await container.dbPool.query<{ starts_at: Date }>(
          `select starts_at from app.weekly_cycles where family_id = $1`,
          [result.family.id],
        );

        await expect(
          container.dbPool.query(
            `insert into app.weekly_cycles (id, family_id, starts_at, ends_at, time_zone, reference_week)
             values ($1, $2, $3, $3 + interval '7 days', 'UTC', current_date)`,
            [randomUUID(), result.family.id, existing.rows[0]!.starts_at],
          ),
        ).rejects.toThrow();
      });
    });
  },
);
