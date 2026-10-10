import { describe, expect, it } from 'vitest';
import {
  CryptoInviteCredentials,
  PASSWORD_ALPHABET,
  PASSWORD_LENGTH,
  createPasswordVerifier,
  hashInviteToken,
} from '../../src/modules/family/infrastructure/crypto-invite-credentials.js';

describe('CryptoInviteCredentials — SPEC-004 CA-05', () => {
  const credentials = new CryptoInviteCredentials('https://app.example.test/');

  it('generates a 6-character password from the unambiguous alphabet and an independent token', async () => {
    const generated = await credentials.generate();
    expect(generated.password).toHaveLength(PASSWORD_LENGTH);
    expect([...generated.password].every((char) => PASSWORD_ALPHABET.includes(char))).toBe(true);
    expect(PASSWORD_ALPHABET).not.toMatch(/[01OI]/);
    expect(generated.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(generated.token).not.toContain(generated.password);
  });

  it('stores the token as SHA-256 and the password as a salted scrypt verifier', async () => {
    const generated = await credentials.generate();
    expect(generated.tokenHash).toBe(hashInviteToken(generated.token));
    expect(generated.tokenHash).toMatch(/^[0-9a-f]{64}$/);
    const [algorithm, version, n, r, p, salt, hash] = generated.passwordVerifier.split('$');
    expect([algorithm, version, n, r, p]).toEqual(['scrypt', 'v1', '32768', '8', '1']);
    expect(salt).toBeTruthy();
    expect(hash).toBeTruthy();
    expect(generated.passwordVerifier).not.toContain(generated.password);
  });

  it('salts every verifier, so equal passwords never share a verifier', async () => {
    expect(await createPasswordVerifier('ABC234')).not.toBe(await createPasswordVerifier('ABC234'));
  });

  it('builds the link as <base>/invite/<token> without a duplicated slash', () => {
    expect(credentials.buildLink('tok')).toBe('https://app.example.test/invite/tok');
  });
});
