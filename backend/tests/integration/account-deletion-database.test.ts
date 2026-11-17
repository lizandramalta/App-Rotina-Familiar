/**
 * Exclusão de conta em PostgreSQL real — SPEC-022 CA-01–CA-04, CA-10, CA-12,
 * CA-13, CA-15, CA-16, CA-18, CA-19 e SPEC-001 CA-13 (limpeza do token órfão).
 *
 * O ponto central é CA-12: depois da exclusão da família, nenhuma tabela com
 * `family_id` pode manter linhas dela. A varredura usa `information_schema`, de
 * modo que uma tabela criada no futuro e esquecida na ordem de exclusão faz o
 * teste falhar.
 */
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { CryptoTokenService } from '../../src/modules/access/infrastructure/crypto-token-service.js';
import { PostgresAccessRepository } from '../../src/modules/access/infrastructure/postgres-access-repository.js';
import { SignInWithAppleUseCase } from '../../src/modules/access/application/sign-in-with-apple-use-case.js';
import { AppleProofRequiredError } from '../../src/modules/account/domain/account-errors.js';
import { PostgresMissionRepository } from '../../src/modules/missions/infrastructure/postgres-mission-repository.js';
import { PostgresMediaObjectDeletionQueue } from '../../src/modules/account/infrastructure/postgres-account-deletion-queues.js';
import type { ActorContext } from '../../src/shared/application/actor-context.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { NotFoundError } from '../../src/shared/domain/domain-error.js';

const INTEGRATION_TIMEOUT_MS = 60_000;

interface SeededFamily {
  readonly familyId: string;
  readonly creatorId: string;
  readonly adultId: string;
  readonly kidsId: string;
  readonly adminId: string;
  readonly identityId: string;
  readonly subject: string;
  readonly futureTaskId: string;
  readonly pastTaskId: string;
  readonly missionId: string;
  readonly adultPhotoKey: string;
  readonly kidsSignalKey: string;
  readonly onboardingKey: string;
}

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Account deletion persistence (SPEC-022)',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    let cipher: CryptoTokenService;

    beforeAll(() => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      container = createContainer(loadConfiguration());
      cipher = new CryptoTokenService(container.config.SESSION_SECRET);
    });

    afterAll(async () => {
      await container?.dispose();
    });

    const q = (sql: string, params: unknown[] = []) => container.dbPool.query(sql, params);

    function actorOf(
      familyId: string,
      memberId: string,
      role: MemberRole,
      isFamilyCreator = false,
    ): ActorContext {
      return { sessionId: randomUUID(), familyId, memberId, role, isFamilyCreator };
    }

    /** Família com dados em praticamente todas as tabelas do produto. */
    async function seedFamily(options: { storedAppleToken?: string } = {}): Promise<SeededFamily> {
      const s = {
        familyId: randomUUID(),
        creatorId: randomUUID(),
        adultId: randomUUID(),
        kidsId: randomUUID(),
        adminId: randomUUID(),
        identityId: randomUUID(),
        subject: `001234.deletion.${randomUUID()}`,
        futureTaskId: randomUUID(),
        pastTaskId: randomUUID(),
        missionId: randomUUID(),
        adultPhotoKey: `test/profile/${randomUUID()}.jpg`,
        kidsSignalKey: `test/signal/${randomUUID()}.jpg`,
        onboardingKey: `test/onboarding/${randomUUID()}.jpg`,
      };
      const templateId = randomUUID();
      const routineId = randomUUID();
      const completionId = randomUUID();
      const sessionId = randomUUID();
      const creatorSessionId = randomUUID();
      const pushId = randomUUID();
      const adultPhotoId = randomUUID();
      const memberBadgeId = randomUUID();
      const cycleId = randomUUID();
      const highlightId = randomUUID();
      const applauseId = randomUUID();
      const grantId = randomUUID();

      await q(`insert into app.families (id, name) values ($1, 'Família Exclusão')`, [s.familyId]);
      await q(
        `insert into app.creator_identities (id, apple_subject_hash, apple_subject_encrypted, apple_refresh_token_encrypted)
         values ($1, $2, $3, $4)`,
        [
          s.identityId,
          cipher.hashAppleSubject(s.subject),
          cipher.encryptAppleSubject(s.subject),
          options.storedAppleToken === undefined ? null : cipher.encrypt(options.storedAppleToken),
        ],
      );
      await q(
        `insert into app.members (id, family_id, creator_identity_id, role, is_family_creator, display_name)
         values ($1, $2, $3, 'administrator', true, 'Criadora')`,
        [s.creatorId, s.familyId, s.identityId],
      );
      for (const [id, role, name] of [
        [s.adultId, 'member', 'Adulto'],
        [s.kidsId, 'kids', 'Criança'],
        [s.adminId, 'administrator', 'Admin'],
      ] as const) {
        await q(
          `insert into app.members (id, family_id, role, is_family_creator, display_name, nickname)
           values ($1, $2, $3, false, $4, 'apelido')`,
          [id, s.familyId, role, name],
        );
      }
      await q(
        `insert into app.media_assets (id, family_id, owner_member_id, object_key, purpose, state)
         values ($1, $2, $3, $4, 'PROFILE_PHOTO', 'READY'), ($5, $2, $6, $7, 'TASK_SIGNAL', 'READY')`,
        [
          adultPhotoId,
          s.familyId,
          s.adultId,
          s.adultPhotoKey,
          randomUUID(),
          s.kidsId,
          s.kidsSignalKey,
        ],
      );
      await q(`update app.members set photo_media_id = $2 where id = $1`, [
        s.adultId,
        adultPhotoId,
      ]);

      for (const [id, member] of [
        [sessionId, s.adultId],
        [creatorSessionId, s.creatorId],
      ] as const) {
        await q(
          `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
           values ($1, $2, $3, $4, 'proof')`,
          [id, s.familyId, member, randomUUID()],
        );
        await q(
          `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
           values ($1, $2, $3, now() + interval '15 minutes')`,
          [randomUUID(), id, randomUUID()],
        );
      }
      await q(
        `insert into app.push_devices (id, session_id, device_token, environment) values ($1, $2, 'device', 'development')`,
        [pushId, sessionId],
      );
      await q(
        `insert into app.member_invites (id, family_id, member_id, issued_by_member_id, token_hash, password_verifier, created_at)
         values ($1, $2, $3, $4, $5, 'verifier', now())`,
        [randomUUID(), s.familyId, s.adultId, s.creatorId, randomUUID()],
      );

      await q(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Lavar louça', 2, now(), now())`,
        [templateId, s.familyId],
      );
      await q(
        `insert into app.routines (id, family_id, task_template_id, frequency_days, start_date, created_at, updated_at)
         values ($1, $2, $3, 7, current_date, now(), now())`,
        [routineId, s.familyId, templateId],
      );
      await q(
        `insert into app.routine_assignees (family_id, routine_id, member_id) values ($1, $2, $3)`,
        [s.familyId, routineId, s.adultId],
      );
      for (const [id, offset, status] of [
        [s.futureTaskId, 10, 'pending'],
        [s.pastTaskId, -10, 'completed'],
      ] as const) {
        await q(
          `insert into app.task_occurrences (id, family_id, task_template_id, origin_key, original_date, scheduled_date, title, weight, status, created_at, updated_at)
           values ($1, $2, $3, $4, current_date + $5::int, current_date + $5::int, 'Lavar louça', 2, $6, now(), now())`,
          [id, s.familyId, templateId, randomUUID(), offset, status],
        );
        await q(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [s.familyId, id, s.adultId],
        );
        await q(
          `insert into app.task_events (id, family_id, task_id, actor_id, event_type, created_at) values ($1, $2, $3, $4, 'created', now())`,
          [randomUUID(), s.familyId, id, s.creatorId],
        );
      }
      await q(
        `insert into app.completions (id, family_id, task_id, performed_by_id, completed_at) values ($1, $2, $3, $4, now())`,
        [completionId, s.familyId, s.pastTaskId, s.adultId],
      );
      await q(
        `insert into app.completion_credits (completion_id, family_id, member_id, weight) values ($1, $2, $3, 2)`,
        [completionId, s.familyId, s.adultId],
      );
      // Sinalização numa tarefa passada: uma sinalização aberta protegeria a
      // tarefa futura da retirada de responsáveis (RN10).
      await q(
        `insert into app.kids_signals (id, family_id, task_id, signaled_by_id) values ($1, $2, $3, $4)`,
        [randomUUID(), s.familyId, s.pastTaskId, s.kidsId],
      );
      await q(`insert into app.missions (id, family_id, title) values ($1, $2, 'Missão')`, [
        s.missionId,
        s.familyId,
      ]);
      await q(
        `insert into app.mission_tasks (family_id, mission_id, task_id) values ($1, $2, $3)`,
        [s.familyId, s.missionId, s.pastTaskId],
      );
      await q(
        `insert into app.mission_participations (family_id, mission_id, member_id, recorded_at) values ($1, $2, $3, now())`,
        [s.familyId, s.missionId, s.adultId],
      );
      await q(
        `insert into app.member_badges (id, family_id, member_id, badge_code, awarded_at) values ($1, $2, $3, 'bronze', now())`,
        [memberBadgeId, s.familyId, s.adultId],
      );
      await q(
        `insert into app.badge_participations (member_badge_id, mission_id, member_id) values ($1, $2, $3)`,
        [memberBadgeId, s.missionId, s.adultId],
      );
      await q(
        `insert into app.reward_items (id, family_id, title, normalized_title, source, created_by_id, created_at)
         values ($1, $2, 'Pizza', 'pizza', 'custom', $3, now())`,
        [randomUUID(), s.familyId, s.creatorId],
      );
      await q(
        `insert into app.weekly_cycles (id, family_id, starts_at, ends_at, time_zone, reference_week)
         values ($1, $2, now() - interval '7 days', now(), 'America/Sao_Paulo', current_date - 7)`,
        [cycleId, s.familyId],
      );
      await q(
        `insert into app.weekly_highlights (id, family_id, cycle_id, starts_at, ends_at, time_zone, reference_week, is_transition, processed_at, winner_count)
         values ($1, $2, $3, now() - interval '7 days', now(), 'America/Sao_Paulo', current_date - 7, false, now(), 1)`,
        [highlightId, s.familyId, cycleId],
      );
      await q(
        `insert into app.weekly_recognitions (id, family_id, highlight_id, member_id, points, completed_tasks) values ($1, $2, $3, $4, 2, 1)`,
        [randomUUID(), s.familyId, highlightId, s.adultId],
      );
      await q(
        `insert into app.family_applause (id, family_id, sender_member_id, recipient_member_id, start_date, end_date)
         values ($1, $2, $3, $4, current_date, current_date)`,
        [applauseId, s.familyId, s.creatorId, s.adultId],
      );
      await q(
        `insert into app.family_applause_push_outbox (id, applause_id, push_device_id) values ($1, $2, $3)`,
        [randomUUID(), applauseId, pushId],
      );
      await q(
        `insert into app.family_time_zone_changes (id, family_id, requested_by_member_id, from_time_zone, to_time_zone, application, status, effective_at, requested_at)
         values ($1, $2, $3, 'America/Sao_Paulo', 'America/Manaus', 'NEXT_CYCLE', 'SCHEDULED', now() + interval '3 days', now())`,
        [randomUUID(), s.familyId, s.creatorId],
      );
      await q(
        `insert into app.family_creation_grants (id, creator_identity_id, grant_token_hash, installation_proof_hash, expires_at)
         values ($1, $2, $3, 'proof', now() - interval '1 hour')`,
        [grantId, s.identityId, randomUUID()],
      );
      await q(
        `insert into app.onboarding_media (id, grant_id, object_key, purpose, state, size_bytes, content_type)
         values ($1, $2, $3, 'PROFILE_PHOTO', 'READY', 10, 'image/jpeg')`,
        [randomUUID(), grantId, s.onboardingKey],
      );

      return s;
    }

    async function rowsLeftForFamily(familyId: string): Promise<Record<string, number>> {
      const tables = await q(
        `select table_name from information_schema.columns
          where table_schema = 'app' and column_name = 'family_id'`,
      );
      const left: Record<string, number> = {};
      for (const { table_name: table } of tables.rows as { table_name: string }[]) {
        const result = await q(`select count(*)::int as n from app.${table} where family_id = $1`, [
          familyId,
        ]);
        const n = (result.rows[0] as { n: number }).n;
        if (n > 0) left[table] = n;
      }
      const family = await q(`select count(*)::int as n from app.families where id = $1`, [
        familyId,
      ]);
      if ((family.rows[0] as { n: number }).n > 0) left.families = 1;
      return left;
    }

    it('CA-01–CA-04 anonymizes a non-creator, revokes access and keeps the history', async () => {
      const s = await seedFamily();

      await container.deleteOwnAccountUseCase.execute(
        actorOf(s.familyId, s.adultId, MemberRole.MEMBER),
      );

      const member = (await q(`select * from app.members where id = $1`, [s.adultId])).rows[0];
      expect(member).toMatchObject({ display_name: null, nickname: null, photo_media_id: null });
      expect(member.deleted_at).not.toBeNull();
      expect(member.removed_at).not.toBeNull();

      const sessions = await q(
        `select revoked_at, revoked_reason from app.sessions where member_id = $1`,
        [s.adultId],
      );
      expect(sessions.rows).toEqual([
        { revoked_at: expect.any(Date), revoked_reason: 'ACCOUNT_DELETED' },
      ]);
      const tokens = await q(
        `select count(*)::int as n from app.session_access_tokens t join app.sessions s on s.id = t.session_id
          where s.member_id = $1 and t.revoked_at is null`,
        [s.adultId],
      );
      expect(tokens.rows[0]).toEqual({ n: 0 });
      const invites = await q(`select status from app.member_invites where member_id = $1`, [
        s.adultId,
      ]);
      expect(invites.rows).toEqual([{ status: 'invalidated' }]);

      // CA-03: sai da tarefa futura pendente, permanece na concluída.
      const assignees = await q(`select task_id from app.task_assignees where member_id = $1`, [
        s.adultId,
      ]);
      expect(assignees.rows).toEqual([{ task_id: s.pastTaskId }]);

      // CA-02: histórico preservado e apresentado como "Membro removido".
      const credits = await q(
        `select count(*)::int as n from app.completion_credits where member_id = $1`,
        [s.adultId],
      );
      expect(credits.rows[0]).toEqual({ n: 1 });
      const participants = await container.transactionRunner.run((tx) =>
        new PostgresMissionRepository().listParticipations(tx, s.familyId, s.missionId),
      );
      expect(participants).toEqual([{ memberId: s.adultId, displayName: 'Membro removido' }]);

      // CA-04: mídia em DELETING e chave na fila do R2.
      const media = await q(`select state from app.media_assets where object_key = $1`, [
        s.adultPhotoKey,
      ]);
      expect(media.rows).toEqual([{ state: 'DELETING' }]);
      const queued = await q(
        `select count(*)::int as n from app.media_object_deletions where object_key = $1`,
        [s.adultPhotoKey],
      );
      expect(queued.rows[0]).toEqual({ n: 1 });

      // Os demais perfis não são afetados.
      const creatorSession = await q(`select revoked_at from app.sessions where member_id = $1`, [
        s.creatorId,
      ]);
      expect(creatorSession.rows).toEqual([{ revoked_at: null }]);
    });

    it('CA-12/CA-13 deletes every row of the family and the Apple identity, queuing R2 keys and the token', async () => {
      const s = await seedFamily({ storedAppleToken: 'apple-refresh-token' });

      await container.deleteOwnAccountUseCase.execute(
        actorOf(s.familyId, s.creatorId, MemberRole.ADMINISTRATOR, true),
      );

      expect(await rowsLeftForFamily(s.familyId)).toEqual({});
      expect(
        (
          await q(`select count(*)::int as n from app.creator_identities where id = $1`, [
            s.identityId,
          ])
        ).rows[0],
      ).toEqual({
        n: 0,
      });
      expect(
        (
          await q(
            `select count(*)::int as n from app.family_creation_grants where creator_identity_id = $1`,
            [s.identityId],
          )
        ).rows[0],
      ).toEqual({ n: 0 });

      const keys = await q(
        `select object_key from app.media_object_deletions where object_key = any($1::text[]) order by object_key`,
        [[s.adultPhotoKey, s.kidsSignalKey, s.onboardingKey]],
      );
      expect(keys.rows).toHaveLength(3);

      // Sem credenciais Apple no ambiente de teste a tentativa imediata falha e
      // o item fica reagendado, com o token apenas cifrado (CA-13).
      const revocations = await q(
        `select token_encrypted, token_type_hint, attempts from app.apple_token_revocations
          order by created_at desc limit 1`,
      );
      const revocation = revocations.rows[0] as {
        token_encrypted: string;
        token_type_hint: string;
        attempts: number;
      };
      expect(revocation.token_type_hint).toBe('refresh_token');
      expect(revocation.attempts).toBe(1);
      expect(revocation.token_encrypted).not.toContain('apple-refresh-token');
      expect(cipher.decrypt(revocation.token_encrypted)).toBe('apple-refresh-token');
    });

    it('CA-10 keeps the family intact when the creator has no stored token and sends no proof', async () => {
      const s = await seedFamily();

      await expect(
        container.deleteOwnAccountUseCase.execute(
          actorOf(s.familyId, s.creatorId, MemberRole.ADMINISTRATOR, true),
        ),
      ).rejects.toBeInstanceOf(AppleProofRequiredError);

      expect(
        (await q(`select count(*)::int as n from app.members where family_id = $1`, [s.familyId]))
          .rows[0],
      ).toEqual({
        n: 4,
      });
    });

    it('CA-15 treats the same Apple ID as an identity without family after the deletion', async () => {
      const s = await seedFamily({ storedAppleToken: 'apple-refresh-token' });
      await container.deleteOwnAccountUseCase.execute(
        actorOf(s.familyId, s.creatorId, MemberRole.ADMINISTRATOR, true),
      );

      const result = await new SignInWithAppleUseCase({
        repository: new PostgresAccessRepository(),
        tokenVerifier: {
          verifyIdentityProof: async () => ({ subject: s.subject, refreshToken: 'new-refresh' }),
        },
        crypto: cipher,
        secretCipher: cipher,
        transactionRunner: container.transactionRunner,
        clock: container.clock,
        logger: container.logger,
      }).execute({
        identityToken: 'jwt',
        authorizationCode: 'code',
        rawNonce: 'nonce',
        installationProof: 'proof',
      });

      expect(result.outcome).toBe('creationGrant');
      const identity = await q(
        `select apple_refresh_token_encrypted from app.creator_identities where apple_subject_hash = $1`,
        [cipher.hashAppleSubject(s.subject)],
      );
      expect(
        cipher.decrypt(
          (identity.rows[0] as { apple_refresh_token_encrypted: string })
            .apple_refresh_token_encrypted,
        ),
      ).toBe('new-refresh');
    });

    it('CA-16 lets an administrator delete a Kids account, and CA-18 hides it from another family', async () => {
      const s = await seedFamily();
      const other = await seedFamily();

      await expect(
        container.deleteKidsAccountUseCase.execute(
          actorOf(other.familyId, other.adminId, MemberRole.ADMINISTRATOR),
          s.kidsId,
        ),
      ).rejects.toBeInstanceOf(NotFoundError);

      await container.deleteKidsAccountUseCase.execute(
        actorOf(s.familyId, s.adminId, MemberRole.ADMINISTRATOR),
        s.kidsId,
      );

      const kids = (
        await q(`select deleted_at, display_name from app.members where id = $1`, [s.kidsId])
      ).rows[0];
      expect(kids.deleted_at).not.toBeNull();
      expect(kids.display_name).toBeNull();
      const signalMedia = await q(`select state from app.media_assets where object_key = $1`, [
        s.kidsSignalKey,
      ]);
      expect(signalMedia.rows).toEqual([{ state: 'DELETING' }]);
      const signal = await q(
        `select count(*)::int as n from app.kids_signals where signaled_by_id = $1`,
        [s.kidsId],
      );
      expect(signal.rows[0]).toEqual({ n: 1 });
    });

    it('CA-19 applies only one of a concurrent removal and self deletion', async () => {
      const s = await seedFamily();

      const results = await Promise.allSettled([
        container.removeMemberUseCase.execute(
          actorOf(s.familyId, s.adminId, MemberRole.ADMINISTRATOR),
          s.adultId,
        ),
        container.deleteOwnAccountUseCase.execute(
          actorOf(s.familyId, s.adultId, MemberRole.MEMBER),
        ),
      ]);

      expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
      const member = (
        await q(`select removed_at, deleted_at, display_name from app.members where id = $1`, [
          s.adultId,
        ])
      ).rows[0];
      expect(member.removed_at).not.toBeNull();
      // Sem estado parcial: excluído implica anonimizado; removido mantém o nome.
      if (member.deleted_at === null) expect(member.display_name).toBe('Adulto');
      else expect(member.display_name).toBeNull();
    });

    it('marks the media DELETED when its queue item completes', async () => {
      const s = await seedFamily();
      await container.deleteOwnAccountUseCase.execute(
        actorOf(s.familyId, s.adultId, MemberRole.MEMBER),
      );
      const queue = new PostgresMediaObjectDeletionQueue();
      const claimId = randomUUID();

      await container.transactionRunner.run(async (tx) => {
        const [item] = (
          await queue.claimDue(tx, {
            now: new Date(Date.now() + 1000),
            claimId,
            leaseUntil: new Date(Date.now() + 60_000),
            limit: 500,
          })
        ).filter((claimed) => claimed.objectKey === s.adultPhotoKey);
        expect(item).toBeDefined();
        await queue.complete(tx, {
          id: item!.id,
          claimId,
          objectKey: item!.objectKey,
          outcome: 'DELETED',
        });
      });

      const media = await q(`select state from app.media_assets where object_key = $1`, [
        s.adultPhotoKey,
      ]);
      expect(media.rows).toEqual([{ state: 'DELETED' }]);
    });

    it('SPEC-001 CA-13 clears the Apple token of an identity without family once its grants expired', async () => {
      const abandoned = randomUUID();
      const pending = randomUUID();
      for (const id of [abandoned, pending]) {
        await q(
          `insert into app.creator_identities (id, apple_subject_hash, apple_subject_encrypted, apple_refresh_token_encrypted)
           values ($1, $2, 'enc', 'token')`,
          [id, randomUUID()],
        );
      }
      await q(
        `insert into app.family_creation_grants (id, creator_identity_id, grant_token_hash, installation_proof_hash, expires_at)
         values ($1, $2, $3, 'p', now() - interval '1 hour'), ($4, $5, $6, 'p', now() + interval '5 minutes')`,
        [randomUUID(), abandoned, randomUUID(), randomUUID(), pending, randomUUID()],
      );

      await container.cleanOrphanAppleTokens.run();

      const tokens = await q(
        `select id, apple_refresh_token_encrypted as token from app.creator_identities where id = any($1::uuid[])`,
        [[abandoned, pending]],
      );
      const byId = Object.fromEntries(
        (tokens.rows as { id: string; token: string | null }[]).map((r) => [r.id, r.token]),
      );
      expect(byId[abandoned]).toBeNull();
      expect(byId[pending]).toBe('token');
    });
  },
);
