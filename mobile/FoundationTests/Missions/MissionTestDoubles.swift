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

let missionDetailSpyFixture = MissionDetail(
    id: missionRepositorySpyFixture.id,
    title: missionRepositorySpyFixture.title,
    note: nil,
    status: .inProgress,
    tasks: [],
    completedAt: nil,
    progressPercent: 0,
    isRedemptionAvailable: false,
    acceptedReward: nil,
    participations: [],
    createdAt: missionRepositorySpyFixture.createdAt
)

/// Builds a canonical detail projection; Kids-style omissions are expressed by passing `nil`.
func makeMissionDetail(
    status: MissionStatus = .inProgress,
    note: String? = nil,
    tasks: [MissionLinkedTask] = [],
    progressPercent: Double = 0,
    isRedemptionAvailable: Bool? = false,
    acceptedReward: AcceptedMissionReward? = nil,
    participations: [MissionParticipation]? = []
) -> MissionDetail {
    MissionDetail(
        id: missionRepositorySpyFixture.id,
        title: missionRepositorySpyFixture.title,
        note: note,
        status: status,
        tasks: tasks,
        completedAt: status == .completed ? Date(timeIntervalSince1970: 1_760_100_000) : nil,
        progressPercent: progressPercent,
        isRedemptionAvailable: isRedemptionAvailable,
        acceptedReward: acceptedReward,
        participations: participations,
        createdAt: missionRepositorySpyFixture.createdAt
    )
}

/// A lock-protected class rather than an actor, matching `TaskRepositorySpy`'s existing pattern:
/// avoids `await` at every call site in tests that are themselves `@MainActor`-isolated.
final class MissionRepositorySpy: MissionRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var createResult: Result<Mission, Error>
    private var missionResult: Result<MissionDetail, Error>
    private var updateResult: Result<Mission, Error>
    private var missionsResult: Result<MissionCollections, Error>
    private var taskOptionsResult: Result<MissionTaskOptionPage, Error>
    private var acceptResults: [Result<AcceptedMissionReward, Error>] = []
    private var _acceptCalls: [(missionID: UUID, rewardItemID: UUID)] = []
    var acceptCalls: [(missionID: UUID, rewardItemID: UUID)] { lock.withLock { _acceptCalls } }

    private var _createCalls: [CreateMissionCommand] = []
    private var _missionCalls: [UUID] = []
    private var _updateCalls: [UpdateMissionCommand] = []
    private var _taskOptionsCalls: [String?] = []

    private var _missionsCallCount = 0
    var missionsCallCount: Int { lock.withLock { _missionsCallCount } }
    var createCalls: [CreateMissionCommand] { lock.withLock { _createCalls } }
    var missionCalls: [UUID] { lock.withLock { _missionCalls } }
    var updateCalls: [UpdateMissionCommand] { lock.withLock { _updateCalls } }
    var taskOptionsCalls: [String?] { lock.withLock { _taskOptionsCalls } }

    init(
        createResult: Result<Mission, Error> = .success(missionRepositorySpyFixture),
        missionResult: Result<MissionDetail, Error> = .success(missionDetailSpyFixture),
        updateResult: Result<Mission, Error> = .success(missionRepositorySpyFixture),
        missionsResult: Result<MissionCollections, Error> = .success(MissionCollections(inProgress: [], completed: [])),
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

    func mission(id: UUID, accessToken: String) async throws -> MissionDetail {
        lock.withLock { _missionCalls.append(id) }
        return try lock.withLock { missionResult }.get()
    }

    func missions(accessToken: String) async throws -> MissionCollections {
        lock.withLock { _missionsCallCount += 1 }
        return try lock.withLock { missionsResult }.get()
    }

    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission {
        lock.withLock { _updateCalls.append(command) }
        return try updateResult.get()
    }

    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage {
        lock.withLock { _taskOptionsCalls.append(query) }
        return try taskOptionsResult.get()
    }

    func acceptReward(missionID: UUID, rewardItemID: UUID, accessToken: String) async throws -> AcceptedMissionReward {
        let result: Result<AcceptedMissionReward, Error> = lock.withLock {
            _acceptCalls.append((missionID, rewardItemID))
            return acceptResults.isEmpty
                ? .success(AcceptedMissionReward(rewardItemID: rewardItemID, title: "Recompensa"))
                : acceptResults.removeFirst()
        }
        return try result.get()
    }

    /// Scripted results for consecutive `acceptReward` calls.
    func setAcceptResults(_ results: [Result<AcceptedMissionReward, Error>]) {
        lock.withLock { acceptResults = results }
    }

    func setMissionResult(_ result: Result<MissionDetail, Error>) {
        lock.withLock { missionResult = result }
    }

    func setUpdateResult(_ result: Result<Mission, Error>) {
        lock.withLock { updateResult = result }
    }

    func setCreateResult(_ result: Result<Mission, Error>) {
        lock.withLock { createResult = result }
    }

    func setMissionsResult(_ result: Result<MissionCollections, Error>) {
        lock.withLock { missionsResult = result }
    }

    func setTaskOptionsResult(_ result: Result<MissionTaskOptionPage, Error>) {
        lock.withLock { taskOptionsResult = result }
    }
}
