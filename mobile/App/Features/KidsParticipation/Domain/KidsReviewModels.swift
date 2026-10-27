import Foundation

/// One pending Kids signal in the Admin review queue (SPEC-013 §5.2, TEL-015).
nonisolated struct KidsSignalSummary: Identifiable, Sendable, Equatable {
    /// The `signalId`.
    let id: UUID
    let taskID: UUID
    let taskTitle: String
    let signaledByID: UUID
    let childName: String
    let signaledAt: Date
    let hasPhoto: Bool
}

nonisolated struct KidsReviewQueuePage: Sendable, Equatable {
    let items: [KidsSignalSummary]
    let nextCursor: String?
}

nonisolated struct KidsSignalDetail: Sendable, Equatable {
    let id: UUID
    let taskID: UUID
    let taskTitle: String
    let childName: String
    let signaledAt: Date
    let assignees: [String]
    let photoMediaID: UUID?
}

nonisolated enum KidsReviewDecision: String, Encodable, Sendable {
    case confirm
    case reject
}

nonisolated struct KidsDecisionResult: Sendable, Equatable {
    let taskStatus: TaskStatus
    let outcome: String
    let applied: Bool
}

nonisolated enum KidsSignalError: Error, Equatable, Sendable {
    case actionNotAllowed
    case notFound
    case rejected
    case network
    case unavailable
}
