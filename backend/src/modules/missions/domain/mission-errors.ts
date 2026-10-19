import {
  ActionNotAllowedError,
  ConflictError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';

export class MissionManagementNotAllowedError extends ActionNotAllowedError {
  constructor() {
    super('Only administrators can create or edit missions.');
  }
}

export class MissionCompletedProtectedError extends ConflictError {
  constructor() {
    super('A completed mission cannot be edited.', 'MISSION_COMPLETED_PROTECTED');
  }
}

export class MissionWouldHaveNoTasksError extends ConflictError {
  constructor() {
    super('A mission must retain at least one task.', 'MISSION_WOULD_HAVE_NO_TASKS');
  }
}

export class MissionTasksRequiredError extends ValidationError {
  constructor() {
    super('A mission requires at least one task.', { taskIds: ['MISSION_TASKS_REQUIRED'] });
  }
}

export class TaskNotInFamilyError extends ValidationError {
  constructor() {
    super('Each task must belong to the active family.', { taskIds: ['TASK_NOT_IN_FAMILY'] });
  }
}
