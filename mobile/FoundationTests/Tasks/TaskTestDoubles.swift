import Foundation
@testable import FamilyRoutine

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

/// A lock-protected class rather than an actor (matching `UITestCredentialStore`'s existing
/// pattern in this codebase): avoids `await` at every call site in tests that are themselves
/// `@MainActor`-isolated, which is all that's needed for a synchronous, deterministic double.
final class TaskRepositorySpy: TaskRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var createResult: Result<FamilyTask, Error>
    private var taskResult: Result<FamilyTask, Error>
    private var updateResult: Result<FamilyTask, Error>
    private var deleteResult: Result<UUID, Error>

    private var _createCalls: [CreateTaskCommand] = []
    private var _taskCalls: [UUID] = []
    private var _updateCalls: [UpdateTaskCommand] = []
    private var _deleteCalls: [UUID] = []

    var createCalls: [CreateTaskCommand] { lock.withLock { _createCalls } }
    var taskCalls: [UUID] { lock.withLock { _taskCalls } }
    var updateCalls: [UpdateTaskCommand] { lock.withLock { _updateCalls } }
    var deleteCalls: [UUID] { lock.withLock { _deleteCalls } }

    init(
        createResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        taskResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        updateResult: Result<FamilyTask, Error> = .success(taskRepositorySpyFixture),
        deleteResult: Result<UUID, Error> = .success(taskRepositorySpyFixture.id)
    ) {
        self.createResult = createResult
        self.taskResult = taskResult
        self.updateResult = updateResult
        self.deleteResult = deleteResult
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
}

/// `TaskEditorViewModel` only needs `listMembers` from `FamilyRepository`; every other method is unused here.
struct FamilyMembersStub: FamilyRepository {
    var members: [FamilyMember] = []

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
        FamilyMemberPage(items: members, nextCursor: nil)
    }
}
