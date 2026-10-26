import Foundation
@testable import FamilyRoutine

let missionRepositorySpyFixture = Mission(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f2")!,
    familyID: UUID(uuidString: "00000000-0000-0000-0000-0000000000f1")!,
    title: "Casa pronta para o fim de semana",
    note: nil,
    status: .inProgress,
    taskIDs: [],
    completedAt: nil,
    isRedemptionAvailable: false,
    createdAt: Date(timeIntervalSince1970: 1_760_000_000)
)

/// A lock-protected class rather than an actor, matching `TaskRepositorySpy`'s existing pattern:
/// avoids `await` at every call site in tests that are themselves `@MainActor`-isolated.
final class MissionRepositorySpy: MissionRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var createResult: Result<Mission, Error>
    private var missionResult: Result<Mission, Error>
    private var updateResult: Result<Mission, Error>
    private var missionsResult: Result<MissionPage, Error>
    private var taskOptionsResult: Result<MissionTaskOptionPage, Error>

    private var _createCalls: [CreateMissionCommand] = []
    private var _missionCalls: [UUID] = []
    private var _updateCalls: [UpdateMissionCommand] = []
    private var _taskOptionsCalls: [String?] = []

    var createCalls: [CreateMissionCommand] { lock.withLock { _createCalls } }
    var missionCalls: [UUID] { lock.withLock { _missionCalls } }
    var updateCalls: [UpdateMissionCommand] { lock.withLock { _updateCalls } }
    var taskOptionsCalls: [String?] { lock.withLock { _taskOptionsCalls } }

    init(
        createResult: Result<Mission, Error> = .success(missionRepositorySpyFixture),
        missionResult: Result<Mission, Error> = .success(missionRepositorySpyFixture),
        updateResult: Result<Mission, Error> = .success(missionRepositorySpyFixture),
        missionsResult: Result<MissionPage, Error> = .success(MissionPage(items: [], nextCursor: nil)),
        taskOptionsResult: Result<MissionTaskOptionPage, Error> = .success(MissionTaskOptionPage(items: [], nextCursor: nil))
    ) {
        self.createResult = createResult
        self.missionResult = missionResult
        self.updateResult = updateResult
        self.missionsResult = missionsResult
        self.taskOptionsResult = taskOptionsResult
    }

    static var fixture: Mission { missionRepositorySpyFixture }

    func createMission(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission {
        lock.withLock { _createCalls.append(command) }
        return try createResult.get()
    }

    func mission(id: UUID, accessToken: String) async throws -> Mission {
        lock.withLock { _missionCalls.append(id) }
        return try missionResult.get()
    }

    func missions(cursor: String?, accessToken: String) async throws -> MissionPage {
        try missionsResult.get()
    }

    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission {
        lock.withLock { _updateCalls.append(command) }
        return try updateResult.get()
    }

    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage {
        lock.withLock { _taskOptionsCalls.append(query) }
        return try taskOptionsResult.get()
    }

    func setMissionResult(_ result: Result<Mission, Error>) {
        lock.withLock { missionResult = result }
    }

    func setUpdateResult(_ result: Result<Mission, Error>) {
        lock.withLock { updateResult = result }
    }

    func setCreateResult(_ result: Result<Mission, Error>) {
        lock.withLock { createResult = result }
    }

    func setMissionsResult(_ result: Result<MissionPage, Error>) {
        lock.withLock { missionsResult = result }
    }

    func setTaskOptionsResult(_ result: Result<MissionTaskOptionPage, Error>) {
        lock.withLock { taskOptionsResult = result }
    }
}
