import { DomainError } from '../../../shared/domain/domain-error.js';

/**
 * Convite que não pode ser usado: token desconhecido, consumido, invalidado ou
 * de perfil indisponível (CA-04, RN46).
 *
 * Uma única resposta para todas as causas: distingui-las diria a quem sonda se
 * o convite existiu, foi usado ou revogado (RNF18, RNF19).
 */
export class InviteUnavailableError extends DomainError {
  constructor(message = 'The invite is unavailable.') {
    super({ message, code: 'INVITE_UNAVAILABLE', statusCode: 404 });
  }
}

/** Senha incorreta. O convite continua disponível (CA-03). */
export class InvitePasswordInvalidError extends DomainError {
  constructor(message = 'The invite password is incorrect.') {
    super({ message, code: 'INVITE_PASSWORD_INVALID', statusCode: 422 });
  }
}

/** Há sessão anterior válida, mas a troca não foi confirmada (CA-06). */
export class AccessSwitchConfirmationRequiredError extends DomainError {
  constructor(message = 'Switching access must be explicitly confirmed.') {
    super({ message, code: 'ACCESS_SWITCH_CONFIRMATION_REQUIRED', statusCode: 409 });
  }
}

/** Credencial da sessão anterior inválida ou já revogada (SPEC-005 §5.2). */
export class PreviousSessionInvalidError extends DomainError {
  constructor(message = 'The previous session credential is invalid or has been revoked.') {
    super({ message, code: 'SESSION_INVALID', statusCode: 401 });
  }
}

/**
 * Limite de tentativas atingido (RNF21). `retryAfterSeconds` alimenta o header
 * `Retry-After`; é a janela inteira, uma estimativa conservadora.
 */
export class RateLimitedError extends DomainError {
  public readonly retryAfterSeconds: number;

  constructor(retryAfterSeconds: number, message = 'Too many attempts. Try again later.') {
    super({ message, code: 'RATE_LIMITED', statusCode: 429 });
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

/**
 * A resposta do ingresso não pôde ser confirmada. O commit pode ter ocorrido:
 * nunca afirma rollback, e o cliente usa a recuperação específica (CA-07).
 */
export class JoinResultUncertainError extends DomainError {
  constructor(
    message = 'The outcome of the join could not be confirmed. Use the recovery operation.',
  ) {
    super({ message, code: 'JOIN_RESULT_UNCERTAIN', statusCode: 503 });
  }
}

/**
 * Recuperação indisponível: janela expirada, provas incompatíveis, sessão
 * revogada ou sem resultado recuperável. Resposta neutra (CA-08).
 */
export class JoinRecoveryUnavailableError extends DomainError {
  constructor(message = 'The join result is not recoverable.') {
    super({ message, code: 'JOIN_RECOVERY_UNAVAILABLE', statusCode: 404 });
  }
}
