import { DomainError } from '../../../shared/domain/domain-error.js';

/**
 * Prova Apple inválida, inconsistente entre si ou expirada (CA-04, SPEC-001).
 *
 * A mensagem é sempre genérica: distinguir "assinatura inválida" de "nonce
 * divergente" na resposta diria ao chamador qual etapa falhou, e nenhum detalhe
 * da prova pode aparecer em resposta ou log (RNF08, RNF16).
 */
export class AppleProofInvalidError extends DomainError {
  constructor(message = 'The Apple identity proof is invalid or has expired.') {
    super({ message, code: 'APPLE_PROOF_INVALID', statusCode: 401 });
  }
}
