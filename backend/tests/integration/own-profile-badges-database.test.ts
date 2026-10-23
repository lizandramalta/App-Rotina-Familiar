/**
 * Perfil próprio e badges (SPEC-006 Fase 1 / SCRUM-51).
 *
 * PostgreSQL real comprova o que dublês não alcançam: rollback real de
 * `PATCH /me/profile` quando a foto é inválida (CA-09), isolamento entre
 * titulares de marcos (CA-05) e agregação real de participações/badges
 * (CA-10/CA-11), semeadas direto nas tabelas satélite como já é convenção nos
 * demais testes de integração deste projeto.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import {
  GetBadgeContributionsUseCase,
  GetOwnBadgesUseCase,
} from '../../src/modules/profile/application/get-own-badges-use-cases.js';
import { GetOwnProfileUseCase } from '../../src/modules/profile/application/get-own-profile-use-case.js';
import { UpdateOwnProfileUseCase } from '../../src/modules/profile/application/update-own-profile-use-case.js';
import { PostgresProfileRepository } from '../../src/modules/profile/infrastructure/postgres-profile-repository.js';
import { PostgresMediaRepository } from '../../src/modules/media/infrastructure/postgres-media-repository.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import type { Clock } from '../../src/shared/application/clock.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';

const NOW = new Date('2026-10-21T12:00:00.000Z');

interface SeededFamily {
  readonly familyId: string;
  readonly memberId: string;
  readonly otherMemberId: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Own profile and badges persistence — SPEC-006',
  { timeout: 60_000 },
  () => {
    let container: ApplicationContainer;
    const profileRepository = new PostgresProfileRepository();
    const mediaRepository = new PostgresMediaRepository();
    const seededFamilies: SeededFamily[] = [];
    const clock: Clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
    });

    afterAll(async () => {
      if (container !== undefined) {
        for (const family of seededFamilies) {
          // `badge_participations` não carrega `family_id`; remove via o
          // `member_badges` da própria família.
          await container.dbPool.query(
            `delete from app.badge_participations
              where member_badge_id in (select id from app.member_badges where family_id = $1)`,
            [family.familyId],
          );
          // `members.photo_media_id` referencia `media_assets`: limpar membros
          // antes da mídia evita violar essa FK.
          for (const table of [
            'member_badges',
            'mission_participations',
            'missions',
            'members',
            'media_assets',
          ]) {
            await container.dbPool.query(`delete from app.${table} where family_id = $1`, [
              family.familyId,
            ]);
          }
          await container.dbPool.query('delete from app.families where id = $1', [family.familyId]);
        }
      }
      await container?.dispose();
      // Várias famílias semeadas (badges/isolamento): a limpeza sequencial
      // pode passar do timeout padrão de hook (10s).
    }, 60_000);

    const updateOwnProfile = () =>
      new UpdateOwnProfileUseCase({
        profileRepository,
        mediaRepository,
        transactionRunner: container.transactionRunner,
        clock,
      });
    const getOwnProfile = () =>
      new GetOwnProfileUseCase({
        profileRepository,
        transactionRunner: container.transactionRunner,
      });
    const getOwnBadges = () =>
      new GetOwnBadgesUseCase({
        profileRepository,
        transactionRunner: container.transactionRunner,
      });
    const getBadgeContributions = () =>
      new GetBadgeContributionsUseCase({
        profileRepository,
        transactionRunner: container.transactionRunner,
      });

    async function seedFamily(): Promise<SeededFamily> {
      const family = {
        familyId: randomUUID(),
        memberId: randomUUID(),
        otherMemberId: randomUUID(),
      };
      await container.dbPool.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa de teste', 'America/Sao_Paulo', $2, $2)`,
        [family.familyId, NOW],
      );
      for (const [id, displayName] of [
        [family.memberId, 'Maria Silva'],
        [family.otherMemberId, 'João Silva'],
      ] as const) {
        await container.dbPool.query(
          `insert into app.members
            (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
           values ($1, $2, 'member', false, $3, $4, $4)`,
          [id, family.familyId, displayName, NOW],
        );
      }
      seededFamilies.push(family);
      return family;
    }

    function actor(
      family: SeededFamily,
      memberId: string,
      role: ActorContext['role'] = MemberRole.MEMBER,
    ): ActorContext {
      return {
        sessionId: randomUUID(),
        familyId: family.familyId,
        memberId,
        role,
        isFamilyCreator: false,
      };
    }

    async function seedReadyProfilePhoto(
      family: SeededFamily,
      ownerMemberId: string,
    ): Promise<string> {
      const mediaId = randomUUID();
      await container.dbPool.query(
        `insert into app.media_assets
          (id, family_id, owner_member_id, object_key, purpose, state, size_bytes, content_type)
         values ($1, $2, $3, $4, 'PROFILE_PHOTO', 'READY', 1024, 'image/jpeg')`,
        [
          mediaId,
          family.familyId,
          ownerMemberId,
          `test/families/${family.familyId}/profile-photos/${mediaId}.jpg`,
        ],
      );
      return mediaId;
    }

    /** Semeia `count` missões concluídas com participação creditada ao membro. */
    async function seedParticipations(
      family: SeededFamily,
      memberId: string,
      count: number,
    ): Promise<string[]> {
      const missionIds: string[] = [];
      for (let i = 0; i < count; i += 1) {
        const missionId = randomUUID();
        await container.dbPool.query(
          `insert into app.missions (id, family_id, title, completed_at, created_at, updated_at)
           values ($1, $2, $3, $4, $4, $4)`,
          [missionId, family.familyId, `Missão ${i + 1}`, NOW],
        );
        await container.dbPool.query(
          `insert into app.mission_participations (family_id, mission_id, member_id, recorded_at)
           values ($1, $2, $3, $4)`,
          [family.familyId, missionId, memberId, NOW],
        );
        missionIds.push(missionId);
      }
      return missionIds;
    }

    async function seedBadge(
      family: SeededFamily,
      memberId: string,
      badgeCode: string,
      missionIds: readonly string[],
    ): Promise<string> {
      const memberBadgeId = randomUUID();
      await container.dbPool.query(
        `insert into app.member_badges (id, family_id, member_id, badge_code, awarded_at)
         values ($1, $2, $3, $4, $5)`,
        [memberBadgeId, family.familyId, memberId, badgeCode, NOW],
      );
      for (const missionId of missionIds) {
        await container.dbPool.query(
          `insert into app.badge_participations (member_badge_id, mission_id, member_id)
           values ($1, $2, $3)`,
          [memberBadgeId, missionId, memberId],
        );
      }
      return memberBadgeId;
    }

    it('CA-01/CA-02 persists a valid nickname and photo, reading back the canonical profile', async () => {
      const family = await seedFamily();
      const mediaId = await seedReadyProfilePhoto(family, family.memberId);

      const result = await updateOwnProfile().execute({
        actor: actor(family, family.memberId),
        nickname: 'Mari',
        photoMediaId: mediaId,
      });

      expect(result).toMatchObject({
        nickname: 'Mari',
        photoMediaId: mediaId,
        totalParticipations: 0,
      });

      const fetched = await getOwnProfile().execute(actor(family, family.memberId));
      expect(fetched).toMatchObject({ nickname: 'Mari', photoMediaId: mediaId });

      const row = await container.dbPool.query<{ nickname: string; photo_media_id: string }>(
        `select nickname, photo_media_id from app.members where family_id = $1 and id = $2`,
        [family.familyId, family.memberId],
      );
      expect(row.rows).toEqual([{ nickname: 'Mari', photo_media_id: mediaId }]);
    });

    it('CA-01/CA-02 returns familyName and persists a new name for an adult', async () => {
      const family = await seedFamily();

      const result = await updateOwnProfile().execute({
        actor: actor(family, family.memberId),
        name: '  Maria S.  ',
      });
      expect(result).toMatchObject({ name: 'Maria S.', familyName: 'Casa de teste' });

      const fetched = await getOwnProfile().execute(actor(family, family.memberId));
      expect(fetched).toMatchObject({ name: 'Maria S.', familyName: 'Casa de teste' });
    });

    it('CA-14 refuses a Kids name edit without touching the stored name', async () => {
      const family = await seedFamily();

      await expect(
        updateOwnProfile().execute({
          actor: actor(family, family.memberId, MemberRole.KIDS),
          name: 'Outro nome',
        }),
      ).rejects.toMatchObject({ statusCode: 403, code: 'ACTION_NOT_ALLOWED' });

      const row = await container.dbPool.query<{ display_name: string }>(
        `select display_name from app.members where family_id = $1 and id = $2`,
        [family.familyId, family.memberId],
      );
      expect(row.rows).toEqual([{ display_name: 'Maria Silva' }]);
    });

    it('CA-09 rolls back the whole PATCH when the photo is invalid, keeping the previous nickname', async () => {
      const family = await seedFamily();

      await updateOwnProfile().execute({
        actor: actor(family, family.memberId),
        nickname: 'Original',
      });

      await expect(
        updateOwnProfile().execute({
          actor: actor(family, family.memberId),
          nickname: 'Should not persist',
          photoMediaId: randomUUID(), // mídia inexistente
        }),
      ).rejects.toBeInstanceOf(NotFoundError);

      const row = await container.dbPool.query<{ nickname: string }>(
        `select nickname from app.members where family_id = $1 and id = $2`,
        [family.familyId, family.memberId],
      );
      expect(row.rows).toEqual([{ nickname: 'Original' }]);
    });

    it('CA-07 rejects a photo owned by another member in the same family, without persisting', async () => {
      const family = await seedFamily();
      const mediaId = await seedReadyProfilePhoto(family, family.otherMemberId);

      await expect(
        updateOwnProfile().execute({
          actor: actor(family, family.memberId),
          photoMediaId: mediaId,
        }),
      ).rejects.toMatchObject({ code: 'PHOTO_MEDIA_NOT_OWNED' });

      const row = await container.dbPool.query<{ photo_media_id: string | null }>(
        `select photo_media_id from app.members where family_id = $1 and id = $2`,
        [family.familyId, family.memberId],
      );
      expect(row.rows).toEqual([{ photo_media_id: null }]);
    });

    it('CA-10 reports totalParticipations: 0 and nextTier bronze(5) with no participations', async () => {
      const family = await seedFamily();

      const badges = await getOwnBadges().execute(actor(family, family.memberId));

      expect(badges).toEqual({
        totalParticipations: 0,
        nextTier: { code: 'bronze', requiredMissionCount: 5, remaining: 5 },
        awards: [],
      });
    });

    it('CA-10/CA-11 aggregates real participations and returns the bronze award with its contributing missions', async () => {
      const family = await seedFamily();
      const missionIds = await seedParticipations(family, family.memberId, 5);
      const memberBadgeId = await seedBadge(family, family.memberId, 'bronze', missionIds);

      const badges = await getOwnBadges().execute(actor(family, family.memberId));
      expect(badges).toMatchObject({
        totalParticipations: 5,
        nextTier: { code: 'silver', requiredMissionCount: 10, remaining: 5 },
      });
      expect(badges.awards).toEqual([
        {
          awardId: memberBadgeId,
          tier: 'bronze',
          requiredMissionCount: 5,
          awardedAt: NOW.toISOString(),
        },
      ]);

      const contributions = await getBadgeContributions().execute(
        actor(family, family.memberId),
        memberBadgeId,
      );
      expect(contributions.awardId).toBe(memberBadgeId);
      expect(contributions.contributingMissions).toHaveLength(5);
      expect(contributions.contributingMissions.map((m) => m.missionId).sort()).toEqual(
        [...missionIds].sort(),
      );
    });

    it('CA-05 hides a badge award from a different member of the same family, with 404', async () => {
      const family = await seedFamily();
      const missionIds = await seedParticipations(family, family.memberId, 5);
      const memberBadgeId = await seedBadge(family, family.memberId, 'bronze', missionIds);

      await expect(
        getBadgeContributions().execute(actor(family, family.otherMemberId), memberBadgeId),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('CA-05 hides a badge award from a member of a different family, with 404', async () => {
      const owner = await seedFamily();
      const outsider = await seedFamily();
      const missionIds = await seedParticipations(owner, owner.memberId, 5);
      const memberBadgeId = await seedBadge(owner, owner.memberId, 'bronze', missionIds);

      await expect(
        getBadgeContributions().execute(actor(outsider, outsider.memberId), memberBadgeId),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('CA-12 lets a Kids actor read and edit its own profile and badges like an adult', async () => {
      const family = await seedFamily();
      const kid = actor(family, family.memberId, MemberRole.KIDS);

      const updated = await updateOwnProfile().execute({ actor: kid, nickname: 'Kid' });
      expect(updated.nickname).toBe('Kid');

      const badges = await getOwnBadges().execute(kid);
      expect(badges.totalParticipations).toBe(0);
    });
  },
);
