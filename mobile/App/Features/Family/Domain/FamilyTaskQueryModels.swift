import Foundation

/// Inclusive civil dates in the family's time zone (SPEC-009 CA-05/07).
nonisolated struct FamilyDateRange: Equatable, Sendable {
    let startDate: String
    let endDate: String
}

nonisolated struct FamilyProgress: Equatable, Sendable {
    let total: Int
    let completed: Int
    let pending: Int
    let awaitingConfirmation: Int
    let percentage: Double?
}

nonisolated struct FamilyMemberProgress: Equatable, Sendable, Identifiable {
    let memberID: UUID
    let name: String
    let role: MemberRole
    let progress: FamilyProgress

    var id: UUID { memberID }
}

nonisolated struct FamilyOverview: Equatable, Sendable {
    let range: FamilyDateRange
    let familyCreatedAt: String
    let progress: FamilyProgress
    let members: [FamilyMemberProgress]
}

nonisolated enum FamilyTaskStatusFilter: String, CaseIterable, Sendable {
    case all
    case pending
    case awaitingConfirmation
    case completed
}

nonisolated struct FamilyTaskItem: Equatable, Sendable, Identifiable {
    let task: FamilyTask
    let displayStatus: TaskStatus

    var id: UUID { task.id }
}

nonisolated struct FamilyTaskPage: Equatable, Sendable {
    let range: FamilyDateRange
    let items: [FamilyTaskItem]
    let nextCursor: String?
}

nonisolated struct WeeklyReportSnapshot: Equatable, Sendable {
    struct Progress: Equatable, Sendable {
        let total: Int
        let completed: Int
        let percentage: Double?
    }
    struct Member: Equatable, Sendable {
        let displayName: String
        let weight: Int
        let completedTasks: Int
        let percentage: Double?
    }

    let period: FamilyDateRange
    let timeZoneID: String
    let generatedAt: Date
    let isPartial: Bool
    let isTransition: Bool
    let progress: Progress
    let totalWeight: Int
    let members: [Member]
}
