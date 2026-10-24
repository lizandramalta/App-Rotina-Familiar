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

/// One day's personal checklist entry (TEL-010/TEL-040). Wraps `FamilyTask` rather than adding
/// `displayStatus` to it directly, so TEL-012/013 keep depending only on the effective `status`
/// (MA-19): actions, progress and the admin queue always read `task.status`, never `displayStatus`.
nonisolated struct OwnTaskListItem: Equatable, Sendable, Identifiable {
    let task: FamilyTask
    /// Presentation-only label per SPEC-009 §5: adult sees `pending` even when the effective
    /// `status` is `awaitingConfirmation`; Kids sees `awaitingConfirmation` (CA-11).
    let displayStatus: TaskStatus

    var id: UUID { task.id }
}

nonisolated struct OwnTaskPage: Equatable, Sendable {
    let items: [OwnTaskListItem]
    let nextCursor: String?
    /// `YYYY-MM-DD`, the family's creation date — RN49's lower bound for the personal carousel
    /// (SPEC-009 E-05). Same value as `DailyProgress.familyCreatedAt`; both calls return it so
    /// either response alone is enough to compute the carousel's range.
    let familyCreatedAt: String
}

/// `percentage` is `nil` when the backend has nothing to compute it from (e.g. no tasks that day).
nonisolated struct DailyProgress: Equatable, Sendable {
    let total: Int
    let completed: Int
    let percentage: Double?
    /// `YYYY-MM-DD`, the family's creation date — RN49's lower bound for the personal carousel
    /// (SPEC-009 E-05).
    let familyCreatedAt: String
}

/// A mission named in the `MISSION_REOPEN_REQUIRES_CONFIRMATION` conflict body (SPEC-011 §5.2),
/// shown by MOD-006 before the caller confirms. Carries only what the warning displays — not the
/// full `Mission` domain shape, which this module doesn't otherwise model.
nonisolated struct AffectedMission: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
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
    /// `409 TASK_NOT_COMPLETED` on reopening: the task is already `pending`/`awaitingConfirmation`.
    /// Reconciled silently per UX-011 — never shown as a technical error.
    case taskNotCompleted
    /// `409 MISSION_REOPEN_REQUIRES_CONFIRMATION` on reopening: resend with `confirm: true` to proceed (SPEC-011 E-01).
    case missionReopenRequiresConfirmation(missionsAffected: [AffectedMission], hasAcceptedReward: Bool)
}
