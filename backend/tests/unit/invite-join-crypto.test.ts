import { describe, expect, it } from 'vitest';
import { AesGcmInviteJoinEnvelope } from '../../src/modules/access/infrastructure/aes-gcm-invite-join-envelope.js';
import { ScryptInvitePasswordVerifier } from '../../src/modules/access/infrastructure/scrypt-invite-password-verifier.js';
import { createPasswordVerifier } from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';

const SESSION = {
  sessionId: 's',
  memberId: 'm',
  familyId: 'f',
  role: 'kids',
  isFamilyCreator: false,
  accessToken: 'access',
  accessTokenExpiresAt: '2026-10-09T15:15:00.000Z',
  refreshToken: 'refresh',
} as const;

describe('ScryptInvitePasswordVerifier', () => {
  const verifier = new ScryptInvitePasswordVerifier();

  it('accepts the password that produced the verifier and rejects others', async () => {
    const stored = await createPasswordVerifier('K7M2QX');
    await expect(verifier.verify('K7M2QX', stored)).resolves.toBe(true);
    await expect(verifier.verify('K7M2QY', stored)).resolves.toBe(false);
  });

  it.each(['', 'not-a-verifier', 'scrypt$v1$32768$8$1$$', 'scrypt$v9$1$1$1$a$b'])(
    'treats malformed verifier %j as a mismatch',
    async (stored) => {
      await expect(verifier.verify('K7M2QX', stored)).resolves.toBe(false);
    },
  );

  it('refuses absurd cost parameters instead of exhausting memory', async () => {
    await expect(verifier.verify('K7M2QX', 'scrypt$v1$999999999$8$1$c2FsdA$aGFzaA')).resolves.toBe(
      false,
    );
  });
});

describe('AesGcmInviteJoinEnvelope', () => {
  const envelope = new AesGcmInviteJoinEnvelope('test-invite-envelope-key-min-16-chars');
  const attemptId = '5d1c2b0e-5b8a-4d0f-9d6e-1f7a8b9c0d1e';

  it('round-trips the session and hides the credentials', () => {
    const sealed = envelope.seal(attemptId, SESSION);
    expect(sealed).not.toContain('refresh');
    expect(envelope.open(attemptId, sealed)).toEqual(SESSION);
  });

  it('does not open for another attempt, with another key or when tampered', () => {
    const sealed = envelope.seal(attemptId, SESSION);

    expect(() => envelope.open('11111111-1111-4111-8111-111111111111', sealed)).toThrow();
    expect(() =>
      new AesGcmInviteJoinEnvelope('another-envelope-key-min-16-chars').open(attemptId, sealed),
    ).toThrow();

    const [iv, ciphertext, tag] = sealed.split('.');
    const flipped = `${ciphertext?.slice(0, -2) ?? ''}AA`;
    expect(() => envelope.open(attemptId, [iv, flipped, tag].join('.'))).toThrow();
    expect(() => envelope.open(attemptId, 'garbage')).toThrow();
  });
});
