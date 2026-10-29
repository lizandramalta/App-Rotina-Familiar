import Foundation

/// SPEC-008 Fase 1 — only the frequencies accepted by the routine contract (RN14, RF14).
nonisolated enum RoutineFrequency: Int, CaseIterable, Sendable, Codable, Equatable {
    case daily = 1
    case everySevenDays = 7
    case everyFourteenDays = 14
    case everyTwentyOneDays = 21
    case everyTwentyEightDays = 28
}

nonisolated enum RoutineMaterializationState: String, Codable, Sendable, Equatable {
    case pending
    case complete
}

/// The routine configuration is separate from each independently identified task occurrence.
nonisolated struct Routine: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let weight: EffortWeight
    let assigneeIDs: [UUID]
    let note: String?
    let startDate: String
    let frequency: RoutineFrequency
    let isActive: Bool
    let materializationState: RoutineMaterializationState
}

nonisolated struct CreateRoutineCommand: Sendable {
    let title: String
    let weight: EffortWeight
    let assigneeIDs: [UUID]
    let note: String?
    let startDate: String
    let frequency: RoutineFrequency
}

/// MOD-003 — where an edit or deletion opened from a routine occurrence applies (UX-008 §5.3).
nonisolated enum RoutineScope: Equatable, Hashable, Sendable {
    /// Individual edit/deletion of the open occurrence (SPEC-007 routes).
    case onlyThis
    /// The open occurrence and the following ones (SPEC-008 Fase 2, `fromTaskId`).
    case thisAndFuture
}

/// `PATCH /v1/routines/{id}` — only these fields; recurrence and states never change (SPEC-008 E-05, E-08).
nonisolated struct UpdateFutureRoutineCommand: Sendable, Equatable {
    let fromTaskID: UUID
    let title: String
    let weight: EffortWeight
    let assigneeIDs: [UUID]
    let note: String?
}

nonisolated struct UpdateFutureRoutineResult: Sendable, Equatable {
    let routine: Routine
    let updatedTaskIDs: [UUID]
    let preservedTaskIDs: [UUID]
}

nonisolated struct DeleteFutureRoutineTasksResult: Sendable, Equatable {
    let routineID: UUID
    let deletedTaskIDs: [UUID]
    let preservedTaskIDs: [UUID]
}

nonisolated enum RoutineError: Error, Equatable, Sendable {
    case actionNotAllowed
    /// `409 MISSION_COMPLETED_PROTECTED` — the source occurrence belongs to a completed mission.
    case missionProtected
    /// `409 MISSION_WOULD_HAVE_NO_TASKS` — the deletion would leave an in-progress mission empty.
    case missionWouldHaveNoTasks
    case notFound
    case validationFailed([String: [String]])
    case uncertainOutcome
    case network
    case unavailable
    case rejected
}
