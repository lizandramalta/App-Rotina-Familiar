import { DomainError } from '../../../shared/domain/domain-error.js';

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
