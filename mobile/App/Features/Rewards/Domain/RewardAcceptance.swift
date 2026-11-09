import Foundation

/// Outcome of `POST /v1/missions/{missionId}/reward-acceptance` when it isn't a `200`
/// (SPEC-017 §5.1, decisão R-1 do SCRUM-90).
nonisolated enum RewardAcceptanceError: Error, Equatable, Sendable {
    /// `409 MISSION_REWARD_ALREADY_ACCEPTED`: another acceptance won (CA-05/RN53).
    case alreadyAccepted
    /// `409 MISSION_REWARD_REDEMPTION_UNAVAILABLE`, `404` or `403`: redemption is no longer open here.
    case unavailable
    /// Network failure, lost response or `5xx`: the accept may or may not exist (CA-07).
    case uncertain
    /// Any other definitive refusal (`422`, `400`, `401`…): nothing was saved.
    case rejected
}

/// What the canonical mission says after an uncertain or failed acceptance (SPEC-017 §5.2).
nonisolated enum RewardAcceptanceReconciliation: Equatable, Sendable {
    /// The accepted snapshot is the item this Administrador chose: treat as confirmed.
    case acceptedByMe(AcceptedMissionReward)
    /// Another item was accepted meanwhile.
    case acceptedByOther
    /// Still completed without reward: a new attempt is allowed.
    case stillAvailable
    /// Not redeemable anymore (reopened, missing or not visible).
    case unavailable
}
