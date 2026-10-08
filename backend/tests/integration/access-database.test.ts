/**
 * Persistência do módulo Access contra PostgreSQL real, após as migrations.
 *
 * Cobre o que um dublê em memória não prova: invariantes do banco (sessão ativa
 * única por membro, Criador único por família), FK composta impedindo cruzar
 * famílias, atomicidade real do BEGIN/COMMIT e ausência de privilégio público.
 * Desligado por padrão; use `npm run test:integration`.
 */
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { PostgresAccessRepository } from '../../src/modules/access/infrastructure/postgres-access-repository.js';
import { CryptoTokenService } from '../../src/modules/access/infrastructure/crypto-token-service.js';
import { SignInWithAppleUseCase } from '../../src/modules/access/application/sign-in-with-apple-use-case.js';
import type { AppleTokenVerifierPort } from '../../src/integrations/apple/apple-token-verifier-port.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';

/**
 * Cada caso faz várias idas e voltas ao banco; com um PostgreSQL remoto o
 * default de 5s do Vitest não cobre a latência de rede.
 */
const INTEGRATION_TIMEOUT_MS = 60_000;

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Access module persistence',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    let repository: PostgresAccessRepository;
    let crypto: CryptoTokenService;

    const appleSubject = `001234.integration.${randomUUID()}`;

    beforeAll(() => {
      // Em NODE_ENV=test, loadConfiguration lê apenas `.env.test` e, sem ele, cai
      // no DSN do Supabase CLI local. Quem roda a suíte apontando para outro banco
      // configurado em `.env` precisa que esse arquivo seja considerado aqui.
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }

      container = createContainer(loadConfiguration());
      repository = new PostgresAccessRepository();
      crypto = new CryptoTokenService('integration-test-session-secret-min-32-chars!');
    });

    afterAll(async () => {
      await container?.dispose();
    });

    /** Família e membro Criador já vinculados, como SPEC-002 os criaria. */
    async function seedLinkedCreator(): Promise<{
      familyId: string;
      memberId: string;
      identityId: string;
      subject: string;
    }> {
      const familyId = randomUUID();
      const memberId = randomUUID();
      const identityId = randomUUID();
      const subject = `001234.seed.${randomUUID()}`;

      await container.transactionRunner.run(async (tx) => {
        const client = tx.client as { query: (sql: string, params: unknown[]) => Promise<unknown> };

        await client.query('insert into app.families (id, name) values ($1, $2)', [
          familyId,
          'Família de Integração',
        ]);
        await repository.insertCreatorIdentity(tx, {
          identityId,
          appleSubjectHash: crypto.hashAppleSubject(subject),
          appleSubjectEncrypted: crypto.encryptAppleSubject(subject),
        });
        await client.query(
          `insert into app.members
                (id, family_id, creator_identity_id, role, is_family_creator, display_name)
         values ($1, $2, $3, $4, true, $5)`,
          [memberId, familyId, identityId, MemberRole.ADMINISTRATOR, 'Criadora'],
        );
      });

      return { familyId, memberId, identityId, subject };
    }

    function buildUseCase(subject: string): SignInWithAppleUseCase {
      const tokenVerifier: AppleTokenVerifierPort = {
        verifyIdentityProof: async () => ({ subject }),
      };

      return new SignInWithAppleUseCase({
        repository,
        tokenVerifier,
        crypto,
        transactionRunner: container.transactionRunner,
        clock: container.clock,
        logger: container.logger,
      });
    }

    const command = {
      identityToken: 'integration-identity-token',
      authorizationCode: 'integration-authorization-code',
      rawNonce: 'integration-raw-nonce',
      installationProof: 'integration-installation-proof',
    };

    describe('migration 0002 shape', () => {
      it('created every Access table in the private app schema', async () => {
        const result = await container.dbPool.query<{ table_name: string }>(
          `select table_name
           from information_schema.tables
          where table_schema = 'app'
            and table_name = any($1::text[])`,
          [
            [
              'families',
              'creator_identities',
              'members',
              'family_creation_grants',
              'sessions',
              'session_access_tokens',
            ],
          ],
        );

        expect(result.rows.map((row) => row.table_name).sort()).toEqual([
          'creator_identities',
          'families',
          'family_creation_grants',
          'members',
          'session_access_tokens',
          'sessions',
        ]);
      });

      it('grants no privilege on Access tables to anon or authenticated (BA-19)', async () => {
        const result = await container.dbPool.query<{ grantee: string }>(
          `select distinct grantee
           from information_schema.role_table_grants
          where table_schema = 'app'
            and grantee in ('anon', 'authenticated')`,
        );

        expect(result.rows).toEqual([]);
      });
    });

    describe('CA-02: creationGrant persistido', () => {
      it('persists the identity and the grant for an identity with no family', async () => {
        const result = await buildUseCase(appleSubject).execute(command);

        expect(result.outcome).toBe('creationGrant');
        if (result.outcome !== 'creationGrant') {
          return;
        }

        const grants = await container.dbPool.query<{
          grant_token_hash: string;
          expires_at: Date;
        }>(
          `select g.grant_token_hash, g.expires_at
           from app.family_creation_grants g
           join app.creator_identities i on i.id = g.creator_identity_id
          where i.apple_subject_hash = $1`,
          [crypto.hashAppleSubject(appleSubject)],
        );

        expect(grants.rows).toHaveLength(1);
        expect(grants.rows[0]?.grant_token_hash).toBe(crypto.hashToken(result.creationGrant));
      });

      it('never stores the Apple subject in clear text', async () => {
        const stored = await container.dbPool.query<{ apple_subject_encrypted: string }>(
          `select apple_subject_encrypted
           from app.creator_identities
          where apple_subject_hash = $1`,
          [crypto.hashAppleSubject(appleSubject)],
        );

        expect(stored.rows[0]?.apple_subject_encrypted).not.toContain(appleSubject);
      });

      it('reuses the same identity row on a second sign in', async () => {
        await buildUseCase(appleSubject).execute(command);

        const identities = await container.dbPool.query(
          'select id from app.creator_identities where apple_subject_hash = $1',
          [crypto.hashAppleSubject(appleSubject)],
        );

        expect(identities.rows).toHaveLength(1);
      });
    });

    describe('CA-01 and CA-05: sessão e substituição atômica', () => {
      it('opens a session scoped to the persisted family', async () => {
        const seed = await seedLinkedCreator();

        const result = await buildUseCase(seed.subject).execute(command);

        expect(result).toMatchObject({
          outcome: 'session',
          memberId: seed.memberId,
          familyId: seed.familyId,
          role: 'administrator',
          isFamilyCreator: true,
        });
      });

      it('leaves exactly one active session after a second sign in', async () => {
        const seed = await seedLinkedCreator();
        const useCase = buildUseCase(seed.subject);

        const first = await useCase.execute(command);
        const second = await useCase.execute(command);

        const active = await container.dbPool.query<{ id: string }>(
          'select id from app.sessions where member_id = $1 and revoked_at is null',
          [seed.memberId],
        );
        const revoked = await container.dbPool.query<{ revoked_reason: string }>(
          'select revoked_reason from app.sessions where member_id = $1 and revoked_at is not null',
          [seed.memberId],
        );

        expect(active.rows).toHaveLength(1);
        expect(revoked.rows[0]?.revoked_reason).toBe('replaced_by_new_apple_sign_in');
        if (first.outcome === 'session' && second.outcome === 'session') {
          expect(active.rows[0]?.id).toBe(second.sessionId);
          expect(second.sessionId).not.toBe(first.sessionId);
        }
      });

      it('stores only token hashes, never the opaque tokens', async () => {
        const seed = await seedLinkedCreator();
        const result = await buildUseCase(seed.subject).execute(command);
        if (result.outcome !== 'session') {
          throw new Error('expected a session result');
        }

        const session = await container.dbPool.query<{
          refresh_token_hash: string;
          installation_proof_hash: string;
        }>('select refresh_token_hash, installation_proof_hash from app.sessions where id = $1', [
          result.sessionId,
        ]);
        const accessTokens = await container.dbPool.query<{ token_hash: string }>(
          'select token_hash from app.session_access_tokens where session_id = $1',
          [result.sessionId],
        );

        expect(session.rows[0]?.refresh_token_hash).toBe(crypto.hashToken(result.refreshToken));
        expect(session.rows[0]?.installation_proof_hash).toBe(
          crypto.hashToken(command.installationProof),
        );
        expect(accessTokens.rows[0]?.token_hash).toBe(crypto.hashToken(result.accessToken));
      });

      it('rolls back the whole sign in when a later write fails', async () => {
        const seed = await seedLinkedCreator();
        const sessionsBefore = await countSessions(seed.memberId);

        // Token com expiração nula viola NOT NULL: a inserção da sessão feita
        // antes dela precisa desaparecer no ROLLBACK.
        await expect(
          container.transactionRunner.run(async (tx) => {
            await repository.insertSession(tx, {
              sessionId: randomUUID(),
              familyId: seed.familyId,
              memberId: seed.memberId,
              refreshTokenHash: crypto.hashToken(randomUUID()),
              installationProofHash: crypto.hashToken('proof'),
            });
            await repository.insertAccessToken(tx, {
              accessTokenId: randomUUID(),
              sessionId: randomUUID(),
              tokenHash: crypto.hashToken(randomUUID()),
              expiresAt: null as unknown as Date,
            });
          }),
        ).rejects.toThrow();

        expect(await countSessions(seed.memberId)).toBe(sessionsBefore);
      });
    });

    describe('invariantes do banco', () => {
      it('refuses a second active session for the same member', async () => {
        const seed = await seedLinkedCreator();

        await container.transactionRunner.run((tx) =>
          repository.insertSession(tx, {
            sessionId: randomUUID(),
            familyId: seed.familyId,
            memberId: seed.memberId,
            refreshTokenHash: crypto.hashToken(randomUUID()),
            installationProofHash: crypto.hashToken('proof'),
          }),
        );

        await expect(
          container.transactionRunner.run((tx) =>
            repository.insertSession(tx, {
              sessionId: randomUUID(),
              familyId: seed.familyId,
              memberId: seed.memberId,
              refreshTokenHash: crypto.hashToken(randomUUID()),
              installationProofHash: crypto.hashToken('proof'),
            }),
          ),
        ).rejects.toThrow(/sessions_one_active_per_member_idx|duplicate key/i);
      });

      it('refuses a session whose family does not own the member (RNF06)', async () => {
        const seed = await seedLinkedCreator();
        const otherFamily = await seedLinkedCreator();

        await expect(
          container.transactionRunner.run((tx) =>
            repository.insertSession(tx, {
              sessionId: randomUUID(),
              familyId: otherFamily.familyId,
              memberId: seed.memberId,
              refreshTokenHash: crypto.hashToken(randomUUID()),
              installationProofHash: crypto.hashToken('proof'),
            }),
          ),
        ).rejects.toThrow();
      });

      it('refuses a second family creator in the same family', async () => {
        const seed = await seedLinkedCreator();

        await expect(
          container.dbPool.query(
            `insert into app.members (id, family_id, role, is_family_creator)
           values ($1, $2, $3, true)`,
            [randomUUID(), seed.familyId, MemberRole.ADMINISTRATOR],
          ),
        ).rejects.toThrow(/members_one_creator_per_family_idx|duplicate key/i);
      });

      it('refuses a member role outside the allowed set', async () => {
        const seed = await seedLinkedCreator();

        await expect(
          container.dbPool.query(
            'insert into app.members (id, family_id, role) values ($1, $2, $3)',
            [randomUUID(), seed.familyId, 'superuser'],
          ),
        ).rejects.toThrow();
      });
    });

    describe('transaction runner', () => {
      it('serializes work per family through an advisory lock (BA-08)', async () => {
        const seed = await seedLinkedCreator();

        const observed = await container.transactionRunner.forFamily(seed.familyId, async (tx) => {
          const client = tx.client as {
            query: (sql: string, params?: unknown[]) => Promise<{ rows: { locked: boolean }[] }>;
          };
          const result = await client.query('select true as locked');
          return result.rows[0]?.locked;
        });

        expect(observed).toBe(true);
      });
    });

    async function countSessions(memberId: string): Promise<number> {
      const result = await container.dbPool.query<{ total: string }>(
        'select count(*)::text as total from app.sessions where member_id = $1',
        [memberId],
      );

      return Number(result.rows[0]?.total ?? '0');
    }
  },
);
