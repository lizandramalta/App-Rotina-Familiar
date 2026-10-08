import {
  createCipheriv,
  createHash,
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual,
} from 'node:crypto';
import type { AccessCryptoPort } from '../application/access-crypto-port.js';

/** 256 bits de entropia no token opaco devolvido ao cliente (BA-10). */
const OPAQUE_TOKEN_BYTES = 32;

const AES_KEY_BYTES = 32;
const AES_IV_BYTES = 12;

/**
 * Sal fixo da derivação da chave AES a partir de `SESSION_SECRET`. Precisa ser
 * estável, senão o valor cifrado não seria mais decifrável entre reinícios; a
 * proteção vem do segredo, não do sal.
 */
const KEY_DERIVATION_SALT = 'app-rotina-familiar/access/apple-subject';

/**
 * Adaptador criptográfico do módulo Access.
 *
 * Tokens opacos nascem aqui e só são devolvidos ao cliente; o banco recebe
 * apenas SHA-256 deles. O `sub` da Apple é cifrado em AES-256-GCM, com a chave
 * derivada de `SESSION_SECRET` — o segredo nunca é usado como chave crua.
 */
export class CryptoTokenService implements AccessCryptoPort {
  private readonly encryptionKey: Buffer;

  constructor(sessionSecret: string) {
    this.encryptionKey = scryptSync(sessionSecret, KEY_DERIVATION_SALT, AES_KEY_BYTES);
  }

  public newId(): string {
    return randomUUID();
  }

  public generateOpaqueToken(): string {
    return randomBytes(OPAQUE_TOKEN_BYTES).toString('base64url');
  }

  public hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  public hashesMatch(left: string, right: string): boolean {
    const leftBuffer = Buffer.from(left, 'utf8');
    const rightBuffer = Buffer.from(right, 'utf8');

    // `timingSafeEqual` exige o mesmo tamanho; hashes de tamanhos diferentes já
    // são diferentes, e sair aqui não revela nada sobre o conteúdo.
    if (leftBuffer.length !== rightBuffer.length) {
      return false;
    }

    return timingSafeEqual(leftBuffer, rightBuffer);
  }

  public hashAppleSubject(appleSubject: string): string {
    return createHash('sha256').update(appleSubject).digest('hex');
  }

  /**
   * Formato `iv.ciphertext.authTag`, em base64url. O IV é novo a cada chamada e
   * a tag de autenticação acompanha o valor, para que uma alteração no banco
   * seja detectada na decifragem.
   */
  public encryptAppleSubject(appleSubject: string): string {
    const iv = randomBytes(AES_IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', this.encryptionKey, iv);

    const ciphertext = Buffer.concat([cipher.update(appleSubject, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();

    return [
      iv.toString('base64url'),
      ciphertext.toString('base64url'),
      authTag.toString('base64url'),
    ].join('.');
  }
}
