import {
  ConflictError,
  ForbiddenError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';

export class TaskManagementNotAllowedError extends ForbiddenError {
  constructor() {
    super('Only adult members can manage tasks.', 'ACTION_NOT_ALLOWED');
  }
}

export class TaskAlreadyCompletedError extends ConflictError {
  constructor(message = 'Completed tasks cannot be deleted directly.') {
    super(message, 'TASK_ALREADY_COMPLETED');
  }
}

export class MissionCompletedProtectedError extends ConflictError {
  constructor() {
    super('A task linked to a completed mission cannot be changed.', 'MISSION_COMPLETED_PROTECTED');
  }
}

export class MissionWouldHaveNoTasksError extends ConflictError {
  constructor() {
    super('A mission must retain at least one task.', 'MISSION_WOULD_HAVE_NO_TASKS');
  }
}

export class SignalResolutionRequiredError extends ValidationError {
  constructor() {
    super(
      'A pending Kids signal must be resolved before editing.',
      {
        signalResolution: ['SIGNAL_RESOLUTION_REQUIRED'],
      },
      'SIGNAL_RESOLUTION_REQUIRED',
    );
  }
}
