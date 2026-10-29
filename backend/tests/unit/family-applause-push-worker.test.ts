import { describe, expect, it, vi } from 'vitest';
import { FamilyApplausePushWorker } from '../../src/modules/family/infrastructure/family-applause-push-worker.js';
import type { ApnsPushGateway } from '../../src/integrations/apple/apns-push-gateway.js';
import type { PostgresConnectionPool } from '../../src/shared/infrastructure/postgres/connection-pool.js';

const job = {
  id: '11111111-2222-4333-8444-555555555555',
  applause_id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  push_device_id: '12345678-1234-4234-8234-123456789abc',
  device_token: 'a'.repeat(64),
  environment: 'development',
  sender_name: 'Alex',
  attempts: 0,
};

function makeWorker(status: number) {
  const query = vi.fn(async (sql: string, _params?: unknown[]) => ({
    rows: sql.includes('select o.id') ? [job] : [],
  }));
  const client = { query, release: vi.fn() };
  const db = { getClient: vi.fn(async () => client) } as unknown as PostgresConnectionPool;
  const send = vi.fn(async () => status);
  const gateway = { send } as unknown as ApnsPushGateway;
  return { worker: new FamilyApplausePushWorker(db, gateway), query, send };
}

describe('Family applause APNs worker — SPEC-009 CA-14', () => {
  it('marks APNs acceptance without claiming delivery or read', async () => {
    const { worker, query, send } = makeWorker(200);
    await worker.run();
    expect(send).toHaveBeenCalledWith(job.device_token, 'development', job.applause_id, 'Alex');
    expect(query.mock.calls.some(([sql]) => sql.includes("state = 'acceptedByProvider'"))).toBe(
      true,
    );
    expect(query.mock.calls.some(([sql]) => sql.includes('accepted_at = now()'))).toBe(true);
  });

  it('revokes a token invalidated by APNs and stops retrying it', async () => {
    const { worker, query } = makeWorker(410);
    await worker.run();
    const failed = query.mock.calls.find(([sql]) => sql.includes('set state = $2'));
    expect(failed?.[1]).toEqual([job.id, 'failed', 'HTTP 410']);
    expect(
      query.mock.calls.some(([sql]) => sql.includes('update app.push_devices set revoked_at')),
    ).toBe(true);
  });
});
