import Foundation
@testable import FamilyRoutine

extension TaskRepository {
    func uploadSignalPhoto(_ jpeg: Data, accessToken: String) async throws -> String { throw TaskError.unavailable }
    func signalTask(id: UUID, photoMediaID: String?, accessToken: String) async throws -> FamilyTask { throw TaskError.unavailable }
}

let taskRepositorySpyFixture = FamilyTask(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f1")!,
    title: "Arrumar os brinquedos",
    weight: .medium,
    scheduledDate: "2026-10-10",
    assigneeIDs: [],
    note: nil,
    status: .pending,
    routineID: nil,
    createdAt: Date(timeIntervalSince1970: 1_760_000_000)
)

/// Plain tuples can't conform to `Equatable`, so `reopenCalls` needs a named type to support `==`.
struct ReopenCall: Equatable {
    let id: UUID
    let confirm: Bool
}

actor TaskRequestGate {
    private var waiter: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func wait() async {
        if isReleased { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func release() {
        isReleased = true
        waiter?.resume()
        waiter = nil
    }
}

/// A lock-protected class rather than an actor (matching `UITestCredentialStore`'s existing
/// pattern in this codebase): avoids `await` at every call site in tests that are themselves
/// `@MainActor`-isolated, which is all that's needed for a synchronous, deterministic double.
final class TaskRepositorySpy: TaskRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var createResult: Result<FamilyTask, Error>
    private var taskResult: Result<FamilyTask, Error>
    private var updateResult: Result<FamilyTask, Error>
    private var deleteResult: Result<UUID, Error>
    private var completeResult: Result<FamilyTask, Error>
    private var dailyTasksResult: Result<OwnTaskPage, Error>
    private var dailyProgressResult: Result<DailyProgress, Error>
    private var reopenResult: Result<FamilyTask, Error>
    private let completionGate: TaskRequestGate?

    private var _createCalls: [CreateTaskCommand] = []
    private var _taskCalls: [UUID] = []
    private var _updateCalls: [UpdateTaskCommand] = []
    private var _deleteCalls: [UUID] = []
    private var _completeCalls: [UUID] = []
    private var _dailyTasksCalls: [String] = []
    private var _dailyProgressCalls: [String] = []
    private var _reopenCalls: [ReopenCall] = []

    var createCalls: [CreateTaskCommand] { lock.withLock { _createCalls } }
    var taskCalls: [UUID] { lock.withLock { _taskCalls } }
    var updateCalls: [UpdateTaskCommand] { lock.withLock { _updateCalls } }
    var deleteCalls: [UUID] { lock.withLock { _deleteCalls } }
    var completeCalls: [UUID] { lock.withLock { _completeCalls } }
    var dailyTasksCalls: [String] { lock.withLock { _dailyTasksCalls } }
    var dailyProgressCalls: [String] { lock.withLock { _dailyProgressCalls } }
    var reopenCalls: [ReopenCall] { lock.withLock { _reopenCalls } }

    init(
        createResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        taskResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        updateResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        deleteResult: Result<UUID, Error> = .success(taskRepositorySpyFixture.id),
        completeResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        dailyTasksResult: Result<OwnTaskPage, Error> = .success(
            OwnTaskPage(items: [], nextCursor: nil, familyCreatedAt: "2020-01-01")
        ),
        dailyProgressResult: Result<DailyProgress, Error> = .success(
            DailyProgress(total: 0, completed: 0, percentage: nil, familyCreatedAt: "2020-01-01")
        ),
        reopenResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        completionGate: TaskRequestGate? = nil
    ) {
        self.createResult = createResult
        self.taskResult = taskResult
        self.updateResult = updateResult
        self.deleteResult = deleteResult
        self.completeResult = completeResult
        self.dailyTasksResult = dailyTasksResult
        self.dailyProgressResult = dailyProgressResult
        self.reopenResult = reopenResult
        self.completionGate = completionGate
    }

    static var fixture: FamilyTask { taskRepositorySpyFixture }

    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask {
        lock.withLock { _createCalls.append(command) }
        return try createResult.get()
    }

    func task(id: UUID, accessToken: String) async throws -> FamilyTask {
        lock.withLock { _taskCalls.append(id) }
        return try taskResult.get()
    }

    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask {
        lock.withLock { _updateCalls.append(command) }
        return try updateResult.get()
    }

    func deleteTask(id: UUID, accessToken: String) async throws -> UUID {
        lock.withLock { _deleteCalls.append(id) }
        return try deleteResult.get()
    }

    func completeTask(id: UUID, accessToken: String) async throws -> FamilyTask {
        lock.withLock { _completeCalls.append(id) }
        await completionGate?.wait()
        return try lock.withLock { completeResult }.get()
    }

    func dailyTasks(referenceDate: String, cursor: String?, accessToken: String) async throws -> OwnTaskPage {
        lock.withLock { _dailyTasksCalls.append(referenceDate) }
        return try dailyTasksResult.get()
    }

    func dailyProgress(referenceDate: String, accessToken: String) async throws -> DailyProgress {
        lock.withLock { _dailyProgressCalls.append(referenceDate) }
        return try dailyProgressResult.get()
    }

    func reopenTask(id: UUID, confirm: Bool, accessToken: String) async throws -> FamilyTask {
        lock.withLock { _reopenCalls.append(ReopenCall(id: id, confirm: confirm)) }
        return try reopenResult.get()
    }

    /// Lets a single test sequence a success then a failure across two `load()` calls on the
    /// same view model, mirroring a background refresh going bad (CA-09).
    func setDailyResults(tasks: Result<OwnTaskPage, Error>? = nil, progress: Result<DailyProgress, Error>? = nil) {
        lock.withLock {
            if let tasks { dailyTasksResult = tasks }
            if let progress { dailyProgressResult = progress }
        }
    }

    /// Lets a test sequence a confirmation-required failure then a success across two
    /// `requestReopen()`/`confirmMissionReopen()` calls on the same view model (CA-02/03).
    func setReopenResult(_ result: Result<FamilyTask, Error>) {
        lock.withLock { reopenResult = result }
    }

    /// Lets a test simulate the silent reconciliation reload triggered by `TASK_NOT_COMPLETED`.
    func setTaskResult(_ result: Result<FamilyTask, Error>) {
        lock.withLock { taskResult = result }
    }

    func setCompleteResult(_ result: Result<FamilyTask, Error>) {
        lock.withLock { completeResult = result }
    }
}

/// `TaskEditorViewModel` only needs `listMembers` from `FamilyRepository`; every other method is unused here.
struct FamilyMembersStub: FamilyRepository {
    var members: [FamilyMember] = []
    var pages: [[FamilyMember]] = []
    var listError: FamilyError?

    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily {
        throw FamilyError.unavailable
    }
    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        throw FamilyError.unavailable
    }
    func setProfilePhoto(mediaID: String, accessToken: String) async throws {
        throw FamilyError.unavailable
    }
    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        throw FamilyError.unavailable
    }
    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        throw FamilyError.unavailable
    }
    func listMembers(accessToken: String, cursor: String?) async throws -> FamilyMemberPage {
        if let listError { throw listError }
        if pages.isEmpty { return FamilyMemberPage(items: members, nextCursor: nil) }
        let index = cursor.flatMap(Int.init) ?? 0
        guard pages.indices.contains(index) else { throw FamilyError.unavailable }
        return FamilyMemberPage(items: pages[index], nextCursor: index + 1 < pages.count ? String(index + 1) : nil)
    }
    func getMemberDetail(memberID: UUID, accessToken: String) async throws -> FamilyMemberDetail {
        throw FamilyError.unavailable
    }
    func getFamily(accessToken: String) async throws -> FamilyProfile {
        throw FamilyError.unavailable
    }
    func updateFamilyName(_ name: String, accessToken: String) async throws -> FamilyProfile {
        throw FamilyError.unavailable
    }
    func getFamilySettings(accessToken: String) async throws -> FamilySettings {
        throw FamilyError.unavailable
    }
    func previewFamilyTimeZoneChange(timeZoneID: String, application: TimeZoneApplication, accessToken: String) async throws -> TimeZoneChangePreview {
        throw FamilyError.unavailable
    }
    func changeFamilyTimeZone(timeZoneID: String, application: TimeZoneApplication, accessToken: String) async throws -> FamilySettings {
        throw FamilyError.unavailable
    }
}

let routineRepositorySpyFixture = Routine(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a8")!,
    title: "Regar as plantas",
    weight: .low,
    assigneeIDs: [],
    note: nil,
    startDate: "2026-10-10",
    frequency: .everySevenDays,
    isActive: true,
    materializationState: .pending
)

final class RoutineRepositorySpy: RoutineRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let timeZoneResult: Result<String, Error>
    private let createResult: Result<Routine, Error>
    private let getResult: Result<Routine, Error>
    private var _createCalls: [CreateRoutineCommand] = []
    private var _getCalls: [UUID] = []

    var createCalls: [CreateRoutineCommand] { lock.withLock { _createCalls } }
    var getCalls: [UUID] { lock.withLock { _getCalls } }

    init(
        timeZoneResult: Result<String, Error> = .success("America/Sao_Paulo"),
        createResult: Result<Routine, Error> = .success(routineRepositorySpyFixture),
        getResult: Result<Routine, Error> = .success(routineRepositorySpyFixture)
    ) {
        self.timeZoneResult = timeZoneResult
        self.createResult = createResult
        self.getResult = getResult
    }

    func familyTimeZoneID(accessToken: String) async throws -> String { try timeZoneResult.get() }

    func createRoutine(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine {
        lock.withLock { _createCalls.append(command) }
        return try createResult.get()
    }

    func routine(id: UUID, accessToken: String) async throws -> Routine {
        lock.withLock { _getCalls.append(id) }
        return try getResult.get()
    }
}
