import Foundation

nonisolated enum MissionStatus: String, Codable, Sendable, Equatable {
    case inProgress
    case completed
}

/// Minimal, server-authoritative mission resource (SPEC-014 §5.2) — Fase 2's slice omits
/// progress/participations/reward, which belong to SPEC-016/017. `isRedemptionAvailable` is
/// `nil` whenever the backend omits it for the Kids projection (CA-19); never assumed present.
nonisolated struct Mission: Equatable, Sendable, Identifiable {
    let id: UUID
    let familyID: UUID
    let title: String
    let note: String?
    let status: MissionStatus
    let taskIDs: [UUID]
    let completedAt: Date?
    let isRedemptionAvailable: Bool?
    let createdAt: Date
}

/// TEL-020's list projection (`GET /v1/missions`) — title and status only, no `note`/`taskIds`.
nonisolated struct MissionSummary: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let status: MissionStatus
    let taskCount: Int
    let completedTaskCount: Int
}

nonisolated struct MissionPage: Equatable, Sendable {
    let items: [MissionSummary]
    let nextCursor: String?
}

/// A task as shown inside a mission's context — MOD-007's search results (`GET
/// /v1/missions/task-options`) and TEL-021/022's "Tarefas vinculadas" rows share this one shape,
/// the latter built via `init(familyTask:)` below rather than modeling a second type.
nonisolated struct MissionTaskOption: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let weight: EffortWeight
    /// Civil date in `YYYY-MM-DD`, same wire-string convention as `FamilyTask.scheduledDate`.
    let scheduledDate: String
    let status: TaskStatus
    let assigneeIDs: [UUID]
}

extension MissionTaskOption {
    /// The canonical mission resource only carries bare `taskIds` (SPEC-014 §5.2); TEL-021 and
    /// TEL-022's edit mode hydrate each linked task's title/status via the existing single-task
    /// lookup (`TaskRepository.task(id:)`, the same one TEL-012 already uses) rather than a new
    /// batch endpoint — see the OUT_OF_SCOPE_FINDING recorded for a future batch endpoint.
    init(familyTask: FamilyTask) {
        self.init(
            id: familyTask.id,
            title: familyTask.title,
            weight: familyTask.weight,
            scheduledDate: familyTask.scheduledDate,
            status: familyTask.status,
            assigneeIDs: familyTask.assigneeIDs
        )
    }
}

nonisolated struct MissionTaskOptionPage: Equatable, Sendable {
    let items: [MissionTaskOption]
    let nextCursor: String?
}

nonisolated struct CreateMissionCommand: Sendable {
    let title: String
    let note: String?
    let taskIDs: [UUID]
}

nonisolated struct UpdateMissionCommand: Sendable {
    let missionID: UUID
    let title: String
    let note: String?
    let taskIDs: [UUID]
}

nonisolated enum MissionError: Error, Equatable, Sendable {
    case actionNotAllowed
    case notFound
    /// `409 MISSION_COMPLETED_PROTECTED` (RN58): editing or re-linking a completed mission.
    case completedProtected
    /// `409 MISSION_WOULD_HAVE_NO_TASKS` (RN50): server-side last line of defense behind CA-12's local guard.
    case wouldHaveNoTasks
    case validationFailed([String: [String]])
    /// The write may or may not have been persisted (no `taskId` yet to reconcile against, BA-07) —
    /// only `createMission` throws this; `updateMission` already knows the id and is left as
    /// `.network`/`.unavailable` for the caller to reconcile via `mission(id:)` before retrying.
    case uncertainOutcome
    case rejected
    case network
    case unavailable
}
