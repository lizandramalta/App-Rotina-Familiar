import { describe, expect, it, vi } from 'vitest';
import { FamilyApplauseService } from '../../src/modules/family/infrastructure/family-applause-service.js';
import type { PostgresConnectionPool } from '../../src/shared/infrastructure/postgres/connection-pool.js';
import { MemberRole } from '../../src/shared/domain/member-role.js';
import { TEST_ACTOR } from '../support/build-test-app.js';

const RECIPIENT = 'b1b2c3d4-e5f6-4890-abcd-ef1234567890';
const RANGE = ['2026-10-19', '2026-10-25'] as const;

function makeService(recipientExists = true) {
  const queries: Array<{ sql: string; params?: unknown[] }> = [];
  const query = vi.fn(async (sql: string, params?: unknown[]) => {
    queries.push({ sql, params });
    if (sql.includes('select 1 from app.members'))
      return { rowCount: recipientExists ? 1 : 0, rows: [] };
    return { rowCount: 1, rows: [] };
  });
  const client = { query, release: vi.fn() };
  const db = { getClient: vi.fn(async () => client), query } as unknown as PostgresConnectionPool;
  return { service: new FamilyApplauseService(db), queries };
}

describe('Family applause — SPEC-009 CA-14/15', () => {
  it('records every confirmed tap, including repeated applause for the same member and range', async () => {
    const { service, queries } = makeService();
    const first = await service.send(TEST_ACTOR, RECIPIENT, ...RANGE);
    const second = await service.send(TEST_ACTOR, RECIPIENT, ...RANGE);
    expect(first.id).not.toBe(second.id);
    const inserted = queries.filter(({ sql }) => sql.includes('insert into app.family_applause ('));
    expect(inserted).toHaveLength(2);
    expect(inserted[0]?.params?.slice(1)).toEqual([
      TEST_ACTOR.familyId,
      TEST_ACTOR.memberId,
      RECIPIENT,
      ...RANGE,
    ]);
    expect(
      queries.filter(({ sql }) => sql.includes('insert into app.family_applause_push_outbox')),
    ).toHaveLength(2);
    expect(queries.filter(({ sql }) => sql === 'commit')).toHaveLength(2);
  });

  it('rejects non-admins and self-congratulation before accessing the database', async () => {
    const { service, queries } = makeService();
    await expect(
      service.send({ ...TEST_ACTOR, role: MemberRole.MEMBER }, RECIPIENT, ...RANGE),
    ).rejects.toMatchObject({ code: 'ACTION_NOT_ALLOWED' });
    await expect(service.send(TEST_ACTOR, TEST_ACTOR.memberId, ...RANGE)).rejects.toMatchObject({
      code: 'ACTION_NOT_ALLOWED',
    });
    expect(queries).toHaveLength(0);
  });

  it('conceals a missing or other-family recipient and rolls back', async () => {
    const { service, queries } = makeService(false);
    await expect(service.send(TEST_ACTOR, RECIPIENT, ...RANGE)).rejects.toMatchObject({
      code: 'RESOURCE_NOT_FOUND',
    });
    expect(queries.some(({ sql }) => sql === 'rollback')).toBe(true);
    expect(queries.some(({ sql }) => sql.includes('insert into app.family_applause ('))).toBe(
      false,
    );
  });
});
