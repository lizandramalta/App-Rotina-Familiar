import { ConflictError, DomainError } from '../../../shared/domain/domain-error.js';

/**
 * Alvo que não pode receber credenciais: Criador (volta por Apple), o próprio
 * ator ou estado inelegível (SPEC-004 CA-04).
 */
export class InviteNotIssuableError extends ConflictError {
  constructor(message = 'This profile cannot receive an invite.') {
    super(message, 'INVITE_NOT_ISSUABLE');
  }
}

/**
 * Grant ausente, inválido, expirado, já consumido, de outro aparelho ou de uma
 * identidade que já tem família (CA-04). Resposta única: distinguir o motivo
 * diria a quem sonda qual condição falhou.
 */
export class CreationGrantInvalidError extends DomainError {
  constructor(message = 'The creation grant is missing, invalid or no longer usable.') {
    super({ message, code: 'CREATION_GRANT_INVALID', statusCode: 401 });
  }
}
