import { scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import type { InvitePasswordVerifierPort } from '../application/invite-password-verifier-port.js';

const scryptAsync = promisify(scrypt) as (
  password: string,
  salt: Buffer,
  keylen: number,
  options: { N: number; r: number; p: number; maxmem: number },
) => Promise<Buffer>;

/** Formato `scrypt$v1$N$r$p$salt$hash`, gravado pela emissão (SPEC-004, BA-22). */
const VERIFIER_PATTERN = /^scrypt\$v1\$(\d+)\$(\d+)\$(\d+)\$([\w-]+)\$([\w-]+)$/;

/** Teto dos parâmetros lidos do banco, para um registro corrompido não esgotar memória. */
const MAX_COST = 1 << 20;
const MAX_BLOCK = 32;

/**
 * Confere a senha do convite contra o verificador scrypt (BA-09, BA-22).
 * Verificador malformado simplesmente não confere: a resposta ao cliente é a
 * mesma de senha incorreta, sem revelar o estado do registro.
 */
export class ScryptInvitePasswordVerifier implements InvitePasswordVerifierPort {
  public async verify(password: string, verifier: string): Promise<boolean> {
    const match = VERIFIER_PATTERN.exec(verifier);
    if (match === null) {
      return false;
    }

    const [, n, r, p, saltText, hashText] = match;
    const cost = Number(n);
    const blockSize = Number(r);
    const parallelism = Number(p);
    if (
      cost > MAX_COST ||
      blockSize > MAX_BLOCK ||
      parallelism > MAX_BLOCK ||
      saltText === undefined ||
      hashText === undefined
    ) {
      return false;
    }

    const salt = Buffer.from(saltText, 'base64url');
    const expected = Buffer.from(hashText, 'base64url');
    if (salt.length === 0 || expected.length === 0) {
      return false;
    }

    const derived = await scryptAsync(password, salt, expected.length, {
      N: cost,
      r: blockSize,
      p: parallelism,
      maxmem: 128 * cost * blockSize * 2,
    });

    return timingSafeEqual(derived, expected);
  }
}
