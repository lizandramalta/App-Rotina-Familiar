import { SessionExpiredError, SessionRevokedError } from '../domain/access-errors.js';
import type { AccessTokenSessionRecord } from './access-repository-port.js';

/**
 * Decide se um access token ainda autentica, em um único lugar: `GET` e
 * `DELETE /me/session` precisam responder exatamente o mesmo erro para o mesmo
 * estado de sessão (SPEC-001 §5.2).
 *
 * A revogação é verificada antes da expiração: se a sessão foi encerrada,
 * renovar não resolve, e o app precisa saber que deve voltar ao login (CA-05).
 */
export function assertSessionIsActive(
  record: AccessTokenSessionRecord | undefined,
  now: Date,
): AccessTokenSessionRecord {
  // Token desconhecido e token ausente recebem a mesma resposta: dizer que o
  // token não existe no banco revelaria se ele já existiu (RNF08).
  if (record === undefined) {
    throw new SessionExpiredError();
  }

  if (record.sessionRevokedAt !== undefined || record.tokenRevokedAt !== undefined) {
    throw new SessionRevokedError();
  }

  if (record.tokenExpiresAt.getTime() <= now.getTime()) {
    throw new SessionExpiredError();
  }

  return record;
}
