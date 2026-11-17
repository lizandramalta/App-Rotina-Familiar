/**
 * Filas pós-commit da exclusão de conta — SPEC-022 CA-04/CA-13, BA-40.
 * Sucesso e esgotamento apagam o item (e o token cifrado); falha transitória
 * reagenda com atraso crescente; nada é propagado ao chamador da exclusão.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RevokeAppleTokens } from '../../src/modules/account/application/revoke-apple-tokens.js';
import { DeleteMediaObjects } from '../../src/modules/account/application/delete-media-objects.js';
import { nextRetryDelayMs } from '../../src/modules/account/application/post-commit-queue-policy.js';
import type {
  AppleTokenRevocationQueuePort,
  ClaimedAppleTokenRevocation,
  ClaimedMediaObjectDeletion,
  MediaObjectDeletionQueuePort,
} from '../../src/modules/account/application/account-deletion-ports.js';
import type { TransactionRunner } from '../../src/shared/application/transaction-runner.js';
import { CryptoTokenService } from '../../src/modules/access/infrastructure/crypto-token-service.js';
import { createSilentLogger } from './support/access-doubles.js';

const NOW = new Date('2026-11-17T12:00:00.000Z');
const clock = { now: () => NOW, nowIsoString: () => NOW.toISOString() };
const transactionRunner: TransactionRunner = {
  run: async (work) => work({ client: {} }),
  forFamily: async (_familyId, work) => work({ client: {} }),
};

function revocationQueue(items: ClaimedAppleTokenRevocation[]) {
  return {
    claimDue: vi.fn().mockResolvedValue(items),
    claimById: vi.fn().mockResolvedValue(items[0]),
    complete: vi.fn().mockResolvedValue(undefined),
    reschedule: vi.fn().mockResolvedValue(undefined),
  };
}

describe('retry policy', () => {
  it('grows exponentially from one minute and caps at six hours', () => {
    expect(nextRetryDelayMs(1)).toBe(60_000);
    expect(nextRetryDelayMs(2)).toBe(120_000);
    expect(nextRetryDelayMs(4)).toBe(480_000);
    expect(nextRetryDelayMs(20)).toBe(6 * 60 * 60 * 1000);
  });
});

describe('RevokeAppleTokens (SPEC-022 CA-13)', () => {
  const item: ClaimedAppleTokenRevocation = {
    id: 'revocation-1',
    tokenEncrypted: 'cipher(apple-refresh)',
    tokenTypeHint: 'refresh_token',
    attempts: 0,
  };
  let revokeToken: ReturnType<typeof vi.fn>;
  let logger: ReturnType<typeof createSilentLogger>;

  function worker(queue: ReturnType<typeof revocationQueue>, maxAttempts = 3) {
    return new RevokeAppleTokens({
      queue: queue as unknown as AppleTokenRevocationQueuePort,
      revocation: {
        revokeToken: revokeToken as unknown as (t: string, h: 'refresh_token') => Promise<void>,
      },
      secretCipher: {
        encrypt: (value) => `cipher(${value})`,
        decrypt: (value) => {
          const match = /^cipher\((.*)\)$/.exec(value);
          if (match?.[1] === undefined) throw new Error('bad tag');
          return match[1];
        },
      },
      transactionRunner,
      clock,
      logger,
      newId: () => 'claim-1',
      maxAttempts,
    });
  }

  beforeEach(() => {
    revokeToken = vi.fn().mockResolvedValue(undefined);
    logger = createSilentLogger();
  });

  it('revokes the decrypted token and deletes the queue item on success', async () => {
    const queue = revocationQueue([item]);

    await worker(queue).run();

    expect(revokeToken).toHaveBeenCalledWith('apple-refresh', 'refresh_token');
    expect(queue.complete).toHaveBeenCalledWith(expect.anything(), {
      id: 'revocation-1',
      claimId: 'claim-1',
    });
    expect(queue.reschedule).not.toHaveBeenCalled();
  });

  it('reschedules a transient failure with backoff and a sanitized reason', async () => {
    const queue = revocationQueue([item]);
    revokeToken.mockRejectedValue(new Error('apple_token_revocation_unreachable'));

    await worker(queue).run();

    expect(queue.complete).not.toHaveBeenCalled();
    expect(queue.reschedule).toHaveBeenCalledWith(expect.anything(), {
      id: 'revocation-1',
      claimId: 'claim-1',
      attempts: 1,
      nextAttemptAt: new Date(NOW.getTime() + 60_000),
      lastError: 'apple_token_revocation_unreachable',
    });
  });

  it('deletes the item, and so the token, once the attempts are exhausted', async () => {
    const queue = revocationQueue([{ ...item, attempts: 2 }]);
    revokeToken.mockRejectedValue(new Error('apple_token_revocation_rejected'));

    await worker(queue, 3).run();

    expect(queue.complete).toHaveBeenCalled();
    expect(queue.reschedule).not.toHaveBeenCalled();
    expect(logger.error).toHaveBeenCalledWith(
      'apple_token_revocation_failed',
      undefined,
      expect.objectContaining({ exhausted: true }),
    );
  });

  it('discards an undecryptable token instead of retrying forever', async () => {
    const queue = revocationQueue([{ ...item, tokenEncrypted: 'garbage' }]);

    await worker(queue).run();

    expect(revokeToken).not.toHaveBeenCalled();
    expect(queue.complete).toHaveBeenCalled();
  });

  it('never logs the token value', async () => {
    const queue = revocationQueue([item]);
    revokeToken.mockRejectedValue(new Error('apple_token_revocation_rejected'));

    await worker(queue).run();

    const calls = JSON.stringify([
      (logger.info as ReturnType<typeof vi.fn>).mock.calls,
      (logger.warn as ReturnType<typeof vi.fn>).mock.calls,
      (logger.error as ReturnType<typeof vi.fn>).mock.calls,
    ]);
    expect(calls).not.toContain('apple-refresh');
  });

  it('processNow swallows failures so the deletion response is not affected', async () => {
    const queue = revocationQueue([item]);
    queue.claimById.mockRejectedValue(new Error('pool exhausted'));

    await expect(worker(queue).processNow('revocation-1')).resolves.toBeUndefined();
  });

  it('processNow does nothing when another cycle already holds the claim', async () => {
    const queue = revocationQueue([]);
    queue.claimById.mockResolvedValue(undefined);

    await worker(queue).processNow('revocation-1');

    expect(revokeToken).not.toHaveBeenCalled();
  });
});

describe('DeleteMediaObjects (SPEC-022 CA-04)', () => {
  const item: ClaimedMediaObjectDeletion = {
    id: 'deletion-1',
    objectKey: 'test/profile/1.jpg',
    attempts: 0,
  };

  function mediaQueue(items: ClaimedMediaObjectDeletion[]) {
    return {
      claimDue: vi.fn().mockResolvedValue(items),
      complete: vi.fn().mockResolvedValue(undefined),
      reschedule: vi.fn().mockResolvedValue(undefined),
    };
  }

  function worker(queue: ReturnType<typeof mediaQueue>, storageDelete: ReturnType<typeof vi.fn>) {
    return new DeleteMediaObjects({
      queue: queue as unknown as MediaObjectDeletionQueuePort,
      storage: { delete: storageDelete } as never,
      transactionRunner,
      clock,
      logger: createSilentLogger(),
      newId: () => 'claim-1',
      maxAttempts: 2,
    });
  }

  it('deletes the object and marks the media as DELETED', async () => {
    const queue = mediaQueue([item]);
    const storageDelete = vi.fn().mockResolvedValue(undefined);

    await worker(queue, storageDelete).run();

    expect(storageDelete).toHaveBeenCalledWith('test/profile/1.jpg');
    expect(queue.complete).toHaveBeenCalledWith(expect.anything(), {
      id: 'deletion-1',
      claimId: 'claim-1',
      objectKey: 'test/profile/1.jpg',
      outcome: 'DELETED',
    });
  });

  it('reschedules a storage failure and marks FAILED once exhausted', async () => {
    const storageDelete = vi.fn().mockRejectedValue(new Error('r2_unavailable'));

    const first = mediaQueue([item]);
    await worker(first, storageDelete).run();
    expect(first.reschedule).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ attempts: 1 }),
    );

    const last = mediaQueue([{ ...item, attempts: 1 }]);
    await worker(last, storageDelete).run();
    expect(last.complete).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ outcome: 'FAILED' }),
    );
  });
});

describe('CryptoTokenService secret cipher (BA-40)', () => {
  it('round-trips a secret and rejects a value encrypted with another key', () => {
    const cipher = new CryptoTokenService('session-secret-for-tests-min-32-chars');
    const other = new CryptoTokenService('another-session-secret-min-32-chars!!');

    const encrypted = cipher.encrypt('apple-refresh-token');

    expect(encrypted).not.toContain('apple-refresh-token');
    expect(cipher.decrypt(encrypted)).toBe('apple-refresh-token');
    expect(() => other.decrypt(encrypted)).toThrow();
    expect(() => cipher.decrypt('not-a-valid-value')).toThrow();
  });
});
