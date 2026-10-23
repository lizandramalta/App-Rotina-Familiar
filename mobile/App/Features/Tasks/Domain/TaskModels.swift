import Foundation

/// 1 = pouco esforço, 2 = esforço médio, 3 = alto esforço (RN13).
nonisolated enum EffortWeight: Int, Codable, Sendable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

nonisolated enum TaskStatus: String, Codable, Sendable, Equatable {
    case pending
    case awaitingConfirmation
    case completed
}

/// Required on every saved edit of an `awaitingConfirmation` task, regardless of which fields changed (RN66).
nonisolated enum SignalResolution: String, Codable, Sendable {
    case resetToPending
    case keepAwaitingConfirmation
}

/// `FamilyTask` is the single occurrence (`OCORRENCIA_TAREFA` in the DER), named to avoid colliding with
/// Swift's concurrency `Task`. The server stays the sole authority; this is a value projection only.
nonisolated struct FamilyTask: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let weight: EffortWeight
    /// Civil date in `YYYY-MM-DD`, kept as the wire string rather than a parsed type (no shared `LocalDate` exists yet).
    let scheduledDate: String
    let assigneeIDs: [UUID]
    let note: String?
    let status: TaskStatus
    let routineID: UUID?
    let createdAt: Date
}

nonisolated struct CreateTaskCommand: Sendable {
    let title: String
    let weight: EffortWeight
    let scheduledDate: String
    let assigneeIDs: [UUID]
    let note: String?
}

/// TEL-013 is a single unified form, not independent partial updates: every save carries the
/// form's complete current values. The contract's field-omission semantics exist for other
/// callers; this command always sets title/weight/scheduledDate/assigneeIDs and sends `note`
/// as `nil` to clear it, never omitting a field.
nonisolated struct UpdateTaskCommand: Sendable {
    let taskID: UUID
    let title: String
    let weight: EffortWeight
    let scheduledDate: String
    let assigneeIDs: [UUID]
    let note: String?
    let signalResolution: SignalResolution?
}

nonisolated enum TaskError: Error, Equatable, Sendable {
    case actionNotAllowed
    case notFound
    case alreadyCompleted
    case missionCompletedProtected
    case missionWouldHaveNoTasks
    case validationFailed([String: [String]])
    case signalResolutionRequired
    /// The write may or may not have been persisted; callers must not retry automatically (BA-07).
    case uncertainOutcome
    /// Definitive 4xx refusal not covered by a more specific case.
    case rejected
    case network
    case unavailable
}
