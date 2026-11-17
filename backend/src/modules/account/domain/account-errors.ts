import { DomainError } from '../../../shared/domain/domain-error.js';

/**
 * O Criador não tem refresh token Apple guardado e não enviou prova Apple nova:
 * o app deve abrir a folha Sign in with Apple e reenviar a exclusão com a prova
 * (SPEC-022 CA-10, RN70).
 */
export class AppleProofRequiredError extends DomainError {
  constructor(message = 'Apple proof is required to delete the family creator account.') {
    super({ message, code: 'APPLE_PROOF_REQUIRED', statusCode: 422 });
  }
}
