import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-007 Mobile CAs for TEL-012: CA-05 to CA-08, CA-15.
@MainActor
struct TaskDetailViewModelTests {
    private func fixture(status: TaskStatus) -> FamilyTask {
        let base = TaskRepositorySpy.fixture
        return FamilyTask(
            id: base.id, title: base.title, weight: base.weight, scheduledDate: base.scheduledDate,
            assigneeIDs: base.assigneeIDs, note: base.note, status: status,
            routineID: base.routineID, createdAt: base.createdAt
        )
    }

    @Test("Loads the task detail on demand")
    func loadsTask() async {
        let task = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = TaskDetailViewModel(taskID: task.id, repository: repository, accessToken: "access-1")

        await viewModel.load()

        #expect(viewModel.task == task)
        #expect(!viewModel.loadFailed)
    }

    @Test("CA-06 a completed task cannot be deleted directly: no confirmation, no request")
    func completedTaskBlocksDeleteDirectly() async {
        let task = fixture(status: .completed)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = TaskDetailViewModel(taskID: task.id, repository: repository, accessToken: "access-1")
        await viewModel.load()

        #expect(!viewModel.canDeleteDirectly)
        viewModel.requestDelete()

        #expect(!viewModel.isConfirmingDelete)
        let deleteCalls = repository.deleteCalls
        #expect(deleteCalls.isEmpty)
    }

    @Test("A pending task can be deleted directly after confirmation")
    func pendingTaskDeletesAfterConfirmation() async {
        let task = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task), deleteResult: .success(task.id))
        let viewModel = TaskDetailViewModel(taskID: task.id, repository: repository, accessToken: "access-1")
        await viewModel.load()

        #expect(viewModel.canDeleteDirectly)
        viewModel.requestDelete()
        #expect(viewModel.isConfirmingDelete)

        await viewModel.confirmDelete()

        #expect(viewModel.isDeleted)
        let deleteCalls = repository.deleteCalls
        #expect(deleteCalls == [task.id])
    }

    @Test("CA-15 deleting an awaitingConfirmation task needs no extra resolution, just removes it")
    func awaitingConfirmationDeletesWithoutExtraStep() async {
        let task = fixture(status: .awaitingConfirmation)
        let repository = TaskRepositorySpy(taskResult: .success(task), deleteResult: .success(task.id))
        let viewModel = TaskDetailViewModel(taskID: task.id, repository: repository, accessToken: "access-1")
        await viewModel.load()

        #expect(viewModel.hasPendingSignal)
        viewModel.requestDelete()
        await viewModel.confirmDelete()

        #expect(viewModel.isDeleted)
    }

    @Test("CA-07 a mission-protected delete surfaces the blocking variant instead of removing the task")
    func missionProtectedDeleteIsBlocked() async {
        let task = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task), deleteResult: .failure(TaskError.missionCompletedProtected))
        let viewModel = TaskDetailViewModel(taskID: task.id, repository: repository, accessToken: "access-1")
        await viewModel.load()

        viewModel.requestDelete()
        await viewModel.confirmDelete()

        #expect(viewModel.deleteBlock == .missionProtected)
        #expect(!viewModel.isDeleted)
    }

    @Test("A failed load reports loadFailed without crashing")
    func loadFailureIsReported() async {
        let repository = TaskRepositorySpy(taskResult: .failure(TaskError.notFound))
        let viewModel = TaskDetailViewModel(taskID: UUID(), repository: repository, accessToken: "access-1")

        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.task == nil)
    }
}
