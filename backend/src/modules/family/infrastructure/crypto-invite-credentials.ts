import { createHash, randomBytes, randomInt, randomUUID, scrypt } from 'node:crypto';
import { promisify } from 'node:util';
import type {
  GeneratedInviteCredentials,
  MemberInviteCredentialsPort,
} from '../application/member-invite-credentials-port.js';

const scryptAsync = promisify(scrypt) as (
  password: string,
  salt: Buffer,
  keylen: number,
  options: { N: number; r: number; p: number; maxmem: number },
) => Promise<Buffer>;

/** 256 bits de entropia no token do link (BA-09). */
const TOKEN_BYTES = 32;

/**
 * Senha de 6 caracteres, digitável por quem a recebe. O alfabeto exclui
 * `0/O` e `1/I` (ambíguos ao ler); sobram 32 símbolos, ou seja, 5 bits por
 * caractere e 30 bits no total. Como é pouca entropia, a defesa vem de um
 * verificador lento (scrypt) e do limite de tentativas no ingresso, não do
 * tamanho da senha.
 */
export const PASSWORD_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
export const PASSWORD_LENGTH = 6;

/** Parâmetros versionados no próprio verificador, para permitir evolução. */
const SCRYPT = { version: 'v1', N: 1 << 15, r: 8, p: 1, saltBytes: 16, keyBytes: 32 } as const;
const SCRYPT_MAX_MEMORY_BYTES = 128 * SCRYPT.N * SCRYPT.r * 2;

const INVITE_PATH = '/invite/';

export function hashInviteToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Formato `scrypt$v1$N$r$p$salt$hash` (base64url), lido pelo ingresso (SPEC-005). */
export async function createPasswordVerifier(password: string): Promise<string> {
  const salt = randomBytes(SCRYPT.saltBytes);
  const derived = await scryptAsync(password, salt, SCRYPT.keyBytes, {
    N: SCRYPT.N,
    r: SCRYPT.r,
    p: SCRYPT.p,
    maxmem: SCRYPT_MAX_MEMORY_BYTES,
  });
  return [
    'scrypt',
    SCRYPT.version,
    SCRYPT.N,
    SCRYPT.r,
    SCRYPT.p,
    salt.toString('base64url'),
    derived.toString('base64url'),
  ].join('$');
}

function generatePassword(): string {
  let password = '';
  for (let index = 0; index < PASSWORD_LENGTH; index += 1) {
    // `randomInt` evita o viés de módulo de um simples `byte % tamanho`.
    password += PASSWORD_ALPHABET.charAt(randomInt(PASSWORD_ALPHABET.length));
  }
  return password;
}

export class CryptoInviteCredentials implements MemberInviteCredentialsPort {
  constructor(private readonly linkBaseUrl: string) {}

  public async generate(): Promise<GeneratedInviteCredentials> {
    const token = randomBytes(TOKEN_BYTES).toString('base64url');
    // Token e senha são independentes: conhecer um não revela o outro.
    const password = generatePassword();
    return {
      inviteId: randomUUID(),
      token,
      password,
      tokenHash: hashInviteToken(token),
      passwordVerifier: await createPasswordVerifier(password),
    };
  }

  public buildLink(token: string): string {
    return `${this.linkBaseUrl.replace(/\/+$/, '')}${INVITE_PATH}${token}`;
  }
}
