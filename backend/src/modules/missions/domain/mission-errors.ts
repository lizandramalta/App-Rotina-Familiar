import {
  ActionNotAllowedError,
  ConflictError,
  DomainError,
  ForbiddenError,
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

/** SPEC-017 CA-02: somente Administrador aceita recompensa de missão. */
export class MissionRewardPermissionError extends ForbiddenError {
  constructor() {
    super('Only administrators can accept a mission reward.', 'INSUFFICIENT_PERMISSIONS');
  }
}

/** SPEC-017 CA-04: missão ainda não concluída, ou sem resgate disponível. */
export class MissionRewardRedemptionUnavailableError extends ConflictError {
  constructor() {
    super('The mission reward is not available for redemption.', 'MISSION_REWARD_REDEMPTION_UNAVAILABLE');
  }
}

/** SPEC-017 CA-05: aceite único — inclusive sob concorrência. */
export class MissionRewardAlreadyAcceptedError extends ConflictError {
  constructor() {
    super('A reward has already been accepted for this mission.', 'MISSION_REWARD_ALREADY_ACCEPTED');
  }
}

/** SPEC-017 CA-03: formato inválido ou item fora do catálogo da família, sem revelar o motivo. */
export class RewardItemNotEligibleError extends DomainError {
  constructor() {
    super({
      message: 'The reward item is not eligible.',
      code: 'REWARD_ITEM_NOT_ELIGIBLE',
      statusCode: 422,
      fieldErrors: { rewardItemId: ['REWARD_ITEM_NOT_ELIGIBLE'] },
    });
  }
}
