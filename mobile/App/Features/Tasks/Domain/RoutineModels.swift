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

nonisolated enum RoutineError: Error, Equatable, Sendable {
    case actionNotAllowed
    case notFound
    case validationFailed([String: [String]])
    case uncertainOutcome
    case network
    case unavailable
    case rejected
}
