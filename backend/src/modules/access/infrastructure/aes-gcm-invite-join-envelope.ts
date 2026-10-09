import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'node:crypto';
import type { InviteJoinEnvelopePort } from '../application/invite-join-envelope-port.js';
import type { IssuedSession } from '../application/session-issuer.js';

const KEY_BYTES = 32;
const IV_BYTES = 12;

/** Sal fixo: precisa ser estável entre reinícios; a proteção vem do segredo. */
const KEY_DERIVATION_SALT = 'app-rotina-familiar/access/invite-join-envelope';

/**
 * Envelope AES-256-GCM das credenciais do ingresso (BA-11). A chave deriva de
 * `INVITE_ENVELOPE_KEY`, que fica fora do banco. O `attemptId` entra como dado
 * autenticado, então um envelope copiado para outra tentativa não abre.
 * Formato: `iv.ciphertext.authTag` em base64url.
 */
export class AesGcmInviteJoinEnvelope implements InviteJoinEnvelopePort {
  private readonly key: Buffer;

  constructor(envelopeKey: string) {
    this.key = scryptSync(envelopeKey, KEY_DERIVATION_SALT, KEY_BYTES);
  }

  public seal(attemptId: string, session: IssuedSession): string {
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    cipher.setAAD(Buffer.from(attemptId, 'utf8'));

    const ciphertext = Buffer.concat([
      cipher.update(JSON.stringify(session), 'utf8'),
      cipher.final(),
    ]);

    return [
      iv.toString('base64url'),
      ciphertext.toString('base64url'),
      cipher.getAuthTag().toString('base64url'),
    ].join('.');
  }

  public open(attemptId: string, envelope: string): IssuedSession {
    const [ivText, ciphertextText, tagText, ...rest] = envelope.split('.');
    if (
      ivText === undefined ||
      ciphertextText === undefined ||
      tagText === undefined ||
      rest.length > 0
    ) {
      throw new Error('Malformed invite join envelope.');
    }

    const decipher = createDecipheriv('aes-256-gcm', this.key, Buffer.from(ivText, 'base64url'));
    decipher.setAAD(Buffer.from(attemptId, 'utf8'));
    decipher.setAuthTag(Buffer.from(tagText, 'base64url'));

    const plaintext = Buffer.concat([
      decipher.update(Buffer.from(ciphertextText, 'base64url')),
      decipher.final(),
    ]).toString('utf8');

    return JSON.parse(plaintext) as IssuedSession;
  }
}
