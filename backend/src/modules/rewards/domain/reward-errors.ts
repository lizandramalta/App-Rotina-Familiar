import { DomainError } from '../../../shared/domain/domain-error.js';

export class RewardPermissionError extends DomainError {
  constructor() {
    super({
      message: 'Only administrators can manage reward items.',
      code: 'INSUFFICIENT_PERMISSIONS',
      statusCode: 403,
    });
  }
}

export class RewardTitleAlreadyExistsError extends DomainError {
  constructor() {
    super({
      message: 'A reward item with this title already exists in the family.',
      code: 'REWARD_TITLE_ALREADY_EXISTS',
      statusCode: 422,
      fieldErrors: { title: ['REWARD_TITLE_ALREADY_EXISTS'] },
    });
  }
}
