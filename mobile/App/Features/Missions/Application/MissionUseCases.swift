import Foundation

struct CreateMissionUseCase: Sendable {
    let repository: any MissionRepository

    func execute(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission {
        try await repository.createMission(command, accessToken: accessToken)
    }
}

struct GetMissionDetailUseCase: Sendable {
    let repository: any MissionRepository

    func execute(missionID: UUID, accessToken: String) async throws -> Mission {
        try await repository.mission(id: missionID, accessToken: accessToken)
    }
}

struct UpdateMissionUseCase: Sendable {
    let repository: any MissionRepository

    func execute(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission {
        try await repository.updateMission(command, accessToken: accessToken)
    }
}

struct ListMissionsUseCase: Sendable {
    let repository: any MissionRepository

    func execute(cursor: String?, accessToken: String) async throws -> MissionPage {
        try await repository.missions(cursor: cursor, accessToken: accessToken)
    }
}

struct GetMissionTaskOptionsUseCase: Sendable {
    let repository: any MissionRepository

    func execute(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage {
        try await repository.taskOptions(query: query, cursor: cursor, accessToken: accessToken)
    }
}

/// Resolves each linked `taskId` via the general single-task lookup (the same one TEL-012 already
/// uses), since the mission resource itself only carries bare ids (SPEC-014 §5.2). Shared by
/// TEL-021 and TEL-022's edit mode. All lookups run in parallel; any single failure fails the
/// whole operation (OUT_OF_SCOPE_FINDING: no batch "tasks by ids" endpoint exists yet).
struct HydrateLinkedTasksUseCase: Sendable {
    let taskRepository: any TaskRepository

    func execute(taskIDs: [UUID], accessToken: String) async throws -> [MissionTaskOption] {
        let repository = taskRepository
        return try await withThrowingTaskGroup(of: (Int, MissionTaskOption).self) { group in
            for (index, taskID) in taskIDs.enumerated() {
                group.addTask {
                    let task = try await repository.task(id: taskID, accessToken: accessToken)
                    return (index, MissionTaskOption(familyTask: task))
                }
            }
            var results: [(Int, MissionTaskOption)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
