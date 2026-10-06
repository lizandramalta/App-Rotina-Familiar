import { describe, it, expect } from 'vitest';
import {
  DomainError,
  NotFoundError,
  ForbiddenError,
  ValidationError,
  ConflictError,
  UnauthorizedError,
} from '../../src/shared/domain/domain-error.js';

describe('Domain Errors', () => {
  it('correctly sets status codes and default error codes', () => {
    const notFound = new NotFoundError('Family not found');
    expect(notFound.statusCode).toBe(404);
    expect(notFound.code).toBe('RESOURCE_NOT_FOUND');
    expect(notFound instanceof DomainError).toBe(true);

    const unauthorized = new UnauthorizedError('Invalid token');
    expect(unauthorized.statusCode).toBe(401);
    expect(unauthorized.code).toBe('UNAUTHORIZED');

    const forbidden = new ForbiddenError('Only admins can perform this action');
    expect(forbidden.statusCode).toBe(403);
    expect(forbidden.code).toBe('FORBIDDEN');

    const conflict = new ConflictError('Task already completed');
    expect(conflict.statusCode).toBe(409);
    expect(conflict.code).toBe('CONFLICT');

    const validation = new ValidationError('Invalid inputs', {
      weight: ['Weight must be between 1 and 3'],
    });
    expect(validation.statusCode).toBe(422);
    expect(validation.fieldErrors?.weight).toContain('Weight must be between 1 and 3');
  });
});
