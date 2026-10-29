import Foundation

nonisolated struct InviteJoinAttempt: Codable, Sendable, Equatable {
    let id: UUID
    let secret: String
    let installationProof: String
}

nonisolated enum InviteJoinError: Error, Sendable, Equatable {
    case inviteUnavailable
    case invalidPassword
    case rateLimited
    case switchConfirmationRequired
    case previousSessionInvalid
    case resultUncertain
    case recoveryUnavailable
    case dependencyUnavailable
    case network
    case invalidResponse
}
