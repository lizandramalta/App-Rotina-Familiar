import Foundation

/// Final weekly highlight of the session owner (SPEC-020 §5, RN65). It is a server snapshot:
/// points and tasks are never recomputed on the device and later corrections don't revise it.
nonisolated struct WeeklyRecognition: Equatable, Identifiable, Sendable {
    let id: UUID
    /// `endsAt` is exclusive: the next cycle's first instant (Monday 00:00 in `timeZoneID`).
    let startsAt: Date
    let endsAt: Date
    let timeZoneID: String
    /// Transition cycles (RN28) may last longer or shorter than seven days; the period shows the real dates.
    let isTransition: Bool
    let points: Int
    let completedTasks: Int
    let isTie: Bool
    let openedAt: Date?

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "America/Sao_Paulo") ?? .current
    }

    /// Last civil day of the cycle (the Sunday before `endsAt`), in the recognition's own time zone.
    var lastDay: Date {
        endsAt.addingTimeInterval(-1)
    }

    /// E-1 (SCRUM-103): the entry card in Minhas tarefas stays while the week following the
    /// recognized cycle is in force — from `endsAt` to seven civil days later in the same time zone.
    func isFeatured(at now: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let featuredUntil = calendar.date(byAdding: .day, value: 7, to: endsAt) else { return false }
        return now >= endsAt && now < featuredUntil
    }
}

nonisolated enum RecognitionError: Error, Equatable, Sendable {
    /// `401`: the session is invalid and must be recovered before trying again (UX-020 §3).
    case sessionExpired
    /// `404`: missing or not owned by the session member. Never reveals someone else's result.
    case notFound
    case network
    case unavailable
}

/// Who reads TEL-052. Kids get the same result without family load or PDF (UX-CA-04).
nonisolated enum RecognitionAudience: Equatable, Sendable {
    case adult
    case kid
}
