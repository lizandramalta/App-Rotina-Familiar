import { ConflictError } from '../../../shared/domain/domain-error.js';

export class TaskNotCompletedError extends ConflictError {
  constructor() {
    super('Only a completed task can be reopened.', 'TASK_NOT_COMPLETED');
  }
}

export class MissionReopenRequiresConfirmationError extends ConflictError {
  constructor(
    public readonly missionsAffected: readonly { readonly id: string; readonly title: string }[],
    public readonly hasAcceptedReward: boolean,
  ) {
    super(
      'Reopening this task affects a completed mission.',
      'MISSION_REOPEN_REQUIRES_CONFIRMATION',
    );
  }
}
