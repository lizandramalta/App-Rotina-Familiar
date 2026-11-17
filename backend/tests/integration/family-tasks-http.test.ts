/** SCRUM-119 repro over real HTTP, like the mobile app actually calls it. */
import { createHash, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { config as loadDotenv } from 'dotenv';
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createContainer, type ApplicationContainer } from '../../src/bootstrap/container.js';
import { loadConfiguration } from '../../src/bootstrap/configuration.js';
import { buildHttpApp } from '../../src/presentation/http/app.js';

const INTEGRATION_TIMEOUT_MS = 120_000;
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');
const NOW = new Date('2026-10-09T12:00:00.000Z');
const REFERENCE_DATE = '2026-10-09';

describe.skipIf(!process.env.RUN_INTEGRATION_TESTS)(
  'Family tasks over HTTP — SCRUM-119',
  { timeout: INTEGRATION_TIMEOUT_MS },
  () => {
    let container: ApplicationContainer;
    let app: FastifyInstance;
    const familyIds: string[] = [];

    beforeAll(async () => {
      const envPath = resolve(process.cwd(), '.env');
      if (process.env.DATABASE_URL === undefined && existsSync(envPath)) {
        loadDotenv({ path: envPath });
      }
      const config = loadConfiguration();
      container = createContainer(config);
      app = buildHttpApp(container, config);
      await app.ready();
    });

    afterAll(async () => {
      if (container !== undefined) {
        await container.dbPool.query('delete from app.task_assignees where family_id = any($1::uuid[])', [
          familyIds,
        ]);
        await container.dbPool.query('delete from app.task_occurrences where family_id = any($1::uuid[])', [
          familyIds,
        ]);
        await container.dbPool.query('delete from app.task_templates where family_id = any($1::uuid[])', [
          familyIds,
        ]);
        await container.dbPool.query('delete from app.families where id = any($1::uuid[])', [
          familyIds,
        ]);
      }
      await app?.close();
      await container?.dispose();
    }, INTEGRATION_TIMEOUT_MS);

    async function seedFamily() {
      const familyId = randomUUID();
      const adminId = randomUUID();
      const otherId = randomUUID();
      const adminToken = `admin-access-${randomUUID()}`;
      const sessionId = randomUUID();
      const db = container.dbPool;
      await db.query(
        `insert into app.families (id, name, timezone, created_at, updated_at)
         values ($1, 'Casa HTTP', 'America/Sao_Paulo', $2, $2)`,
        [familyId, new Date('2026-10-01T12:00:00.000Z')],
      );
      await db.query(
        `insert into app.members (id, family_id, role, is_family_creator, display_name, created_at, updated_at)
         values ($1, $3, 'administrator', true, 'Admin', $4, $4),
                ($2, $3, 'member', false, 'Outro membro', $4, $4)`,
        [adminId, otherId, familyId, NOW],
      );
      await db.query(
        `insert into app.sessions (id, family_id, member_id, refresh_token_hash, installation_proof_hash)
         values ($1, $2, $3, $4, 'admin-proof')`,
        [sessionId, familyId, adminId, `admin-refresh-${sessionId}`],
      );
      await db.query(
        `insert into app.session_access_tokens (id, session_id, token_hash, expires_at)
         values ($1, $2, $3, now() + interval '15 minutes')`,
        [randomUUID(), sessionId, sha256(adminToken)],
      );
      familyIds.push(familyId);
      return { familyId, adminId, otherId, adminToken };
    }

    async function seedTask(
      familyId: string,
      params: { readonly status: 'pending' | 'awaitingConfirmation' | 'completed'; readonly assigneeIds: readonly string[] },
    ): Promise<string> {
      const templateId = randomUUID();
      const taskId = randomUUID();
      await container.dbPool.query(
        `insert into app.task_templates (id, family_id, title, weight, created_at, updated_at)
         values ($1, $2, 'Tarefa de teste', 1, $3, $3)`,
        [templateId, familyId, NOW],
      );
      await container.dbPool.query(
        `insert into app.task_occurrences
           (id, family_id, task_template_id, origin_key, original_date, scheduled_date,
            title, weight, status, created_at, updated_at)
         values ($1, $2, $3, $4, $5, $5, 'Tarefa de teste', 1, $6, $7, $7)`,
        [taskId, familyId, templateId, `single:${taskId}`, REFERENCE_DATE, params.status, NOW],
      );
      for (const memberId of params.assigneeIds) {
        await container.dbPool.query(
          `insert into app.task_assignees (family_id, task_id, member_id) values ($1, $2, $3)`,
          [familyId, taskId, memberId],
        );
      }
      return taskId;
    }

    it('member-filtered pending header count matches the actually listed rows, via the real routes', async () => {
      const family = await seedFamily();
      const exclusivePending = await seedTask(family.familyId, {
        status: 'pending',
        assigneeIds: [family.adminId],
      });
      const sharedPending = await seedTask(family.familyId, {
        status: 'pending',
        assigneeIds: [family.adminId, family.otherId],
      });

      const overviewResponse = await app.inject({
        method: 'GET',
        url: `/v1/family/overview?startDate=${REFERENCE_DATE}&endDate=${REFERENCE_DATE}`,
        headers: { authorization: `Bearer ${family.adminToken}` },
      });
      expect(overviewResponse.statusCode).toBe(200);
      const overview = overviewResponse.json<{
        members: readonly { memberId: string; pending: number }[];
      }>();
      const headerPending = overview.members.find((m) => m.memberId === family.adminId)?.pending;

      const tasksResponse = await app.inject({
        method: 'GET',
        url: `/v1/family/members/${family.adminId}/tasks?startDate=${REFERENCE_DATE}&endDate=${REFERENCE_DATE}`,
        headers: { authorization: `Bearer ${family.adminToken}` },
      });
      expect(tasksResponse.statusCode).toBe(200);
      const page = tasksResponse.json<{
        items: readonly { id: string; displayStatus: string }[];
      }>();
      const pendingRows = page.items.filter((item) => item.displayStatus === 'pending');

      expect(pendingRows.map((item) => item.id).sort()).toEqual(
        [exclusivePending, sharedPending].sort(),
      );
      expect(headerPending).toBe(pendingRows.length);
    });
  },
);
