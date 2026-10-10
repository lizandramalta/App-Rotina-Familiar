/**
 * Base class for all domain and business rule errors.
 *
 * Mapped to RFC 9457 Problem Details by the presentation layer.
 */
export class DomainError extends Error {
  public readonly code: string;
  public readonly statusCode: number;
  public readonly fieldErrors?: Record<string, string[]>;

  constructor(options: {
    message: string;
    code: string;
    statusCode?: number;
    fieldErrors?: Record<string, string[]>;
  }) {
    super(options.message);
    this.name = this.constructor.name;
    this.code = options.code;
    this.statusCode = options.statusCode ?? 400;
    this.fieldErrors = options.fieldErrors;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class NotFoundError extends DomainError {
  constructor(message: string, code = 'RESOURCE_NOT_FOUND') {
    super({ message, code, statusCode: 404 });
  }
}

export class UnauthorizedError extends DomainError {
  constructor(message: string, code = 'UNAUTHORIZED') {
    super({ message, code, statusCode: 401 });
  }
}

export class ForbiddenError extends DomainError {
  constructor(message: string, code = 'FORBIDDEN') {
    super({ message, code, statusCode: 403 });
  }
}

export class ConflictError extends DomainError {
  constructor(message: string, code = 'CONFLICT') {
    super({ message, code, statusCode: 409 });
  }
}

export class ValidationError extends DomainError {
  constructor(message: string, fieldErrors?: Record<string, string[]>, code = 'VALIDATION_FAILED') {
    super({ message, code, statusCode: 422, fieldErrors });
  }
}

/**
 * Dependência (banco, storage) indisponível ou resultado de gravação incerto.
 * Nunca afirma que a gravação foi desfeita (backend-contracts.md §1, 503).
 */
export class DependencyUnavailableError extends DomainError {
  constructor(
    message = 'A required dependency is unavailable. The outcome of the operation is uncertain.',
  ) {
    super({ message, code: 'DEPENDENCY_UNAVAILABLE', statusCode: 503 });
  }
}

/**
 * Sessão válida sem a capacidade exigida pela ação (por exemplo, Membro ou Kids
 * em configurações da família). O papel vem da sessão, nunca do cliente.
 */
export class ActionNotAllowedError extends DomainError {
  constructor(message = 'The current profile is not allowed to perform this action.') {
    super({ message, code: 'ACTION_NOT_ALLOWED', statusCode: 403 });
  }
}
