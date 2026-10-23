import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-007 Mobile CAs for TEL-012: CA-05 to CA-08, CA-15.
/// SPEC-011 Mobile CAs for the Reabrir action: CA-01 to CA-05.
@MainActor
struct TaskDetailViewModelTests {
    private static let adultMemberID = UUID()
    private static let kidMemberID = UUID()

    private func fixture(status: TaskStatus, assigneeIDs: [UUID] = []) -> FamilyTask {
        let base = TaskRepositorySpy.fixture
        return FamilyTask(
            id: base.id, title: base.title, weight: base.weight, scheduledDate: base.scheduledDate,
            assigneeIDs: assigneeIDs, note: base.note, status: status,
            routineID: base.routineID, createdAt: base.createdAt
        )
    }

    private func makeViewModel(
        taskID: UUID,
        role: MemberRole = .administrator,
        currentMemberID: UUID = TaskDetailViewModelTests.adultMemberID,
        repository: TaskRepositorySpy
    ) -> TaskDetailViewModel {
        TaskDetailViewModel(
            taskID: taskID,
            role: role,
            currentMemberID: currentMemberID,
            repository: repository,
            accessToken: "access-1"
        )
    }

    @Test("Loads the task detail on demand")
    func loadsTask() async {
        let task = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)

        await viewModel.load()

        #expect(viewModel.task == task)
        #expect(!viewModel.loadFailed)
    }

    @Test("CA-06 a completed task cannot be deleted directly: no confirmation, no request")
    func completedTaskBlocksDeleteDirectly() async {
        let task = fixture(status: .completed)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
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
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
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
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
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
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        viewModel.requestDelete()
        await viewModel.confirmDelete()

        #expect(viewModel.deleteBlock == .missionProtected)
        #expect(!viewModel.isDeleted)
    }

    @Test("A failed load reports loadFailed without crashing")
    func loadFailureIsReported() async {
        let repository = TaskRepositorySpy(taskResult: .failure(TaskError.notFound))
        let viewModel = makeViewModel(taskID: UUID(), repository: repository)

        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.task == nil)
    }

    @Test("Kids never manage (edit/delete) a task, even their own")
    func kidsNeverManagesTask() async {
        let task = fixture(status: .pending, assigneeIDs: [Self.kidMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, role: .kid, currentMemberID: Self.kidMemberID, repository: repository)
        await viewModel.load()

        #expect(!viewModel.canManageTask)
    }

    @Test("CA-01 Admin/Membro reopens any completed task directly when it has no mission impact")
    func adultReopensDirectlyWithoutImpact() async {
        let task = fixture(status: .completed)
        let reopened = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task), reopenResult: .success(reopened))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        #expect(viewModel.canReopen)
        await viewModel.requestReopen()

        #expect(viewModel.task == reopened)
        #expect(viewModel.showReopenSuccessBanner)
        #expect(viewModel.missionReopenPrompt == nil)
        #expect(repository.reopenCalls == [ReopenCall(id: task.id, confirm: false)])
    }

    @Test("A pending/awaitingConfirmation task never offers Reabrir")
    func reopenHiddenWhenNotCompleted() async {
        let task = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        #expect(!viewModel.canReopen)
    }

    @Test("CA-02/CA-03 mission impact requires confirmation, then resends with confirm: true")
    func reopenRequiresConfirmationThenConfirms() async {
        let task = fixture(status: .completed)
        let missionsAffected = [AffectedMission(id: UUID(), title: "Arrumar o quintal")]
        let repository = TaskRepositorySpy(
            taskResult: .success(task),
            reopenResult: .failure(TaskError.missionReopenRequiresConfirmation(missionsAffected: missionsAffected, hasAcceptedReward: false))
        )
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        await viewModel.requestReopen()

        #expect(viewModel.missionReopenPrompt == MissionReopenPrompt(missionsAffected: missionsAffected, hasAcceptedReward: false))
        #expect(repository.reopenCalls == [ReopenCall(id: task.id, confirm: false)])

        let reopened = fixture(status: .pending)
        repository.setReopenResult(.success(reopened))
        await viewModel.confirmMissionReopen()

        #expect(viewModel.task == reopened)
        #expect(viewModel.missionReopenPrompt == nil)
        #expect(viewModel.showReopenSuccessBanner)
        #expect(repository.reopenCalls == [ReopenCall(id: task.id, confirm: false), ReopenCall(id: task.id, confirm: true)])
    }

    @Test("Cancelling the mission-reopen prompt never calls the server again")
    func cancelMissionReopenDoesNotConfirm() async {
        let task = fixture(status: .completed)
        let repository = TaskRepositorySpy(
            taskResult: .success(task),
            reopenResult: .failure(TaskError.missionReopenRequiresConfirmation(missionsAffected: [], hasAcceptedReward: false))
        )
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()
        await viewModel.requestReopen()
        #expect(viewModel.missionReopenPrompt != nil)

        viewModel.cancelMissionReopen()

        #expect(viewModel.missionReopenPrompt == nil)
        #expect(repository.reopenCalls.count == 1)
    }

    @Test("TASK_NOT_COMPLETED is reconciled silently by reloading, never shown as a technical error")
    func taskNotCompletedReconcilesSilently() async {
        let task = fixture(status: .completed)
        let repository = TaskRepositorySpy(taskResult: .success(task), reopenResult: .failure(TaskError.taskNotCompleted))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        let reconciled = fixture(status: .pending)
        repository.setTaskResult(.success(reconciled))
        await viewModel.requestReopen()

        #expect(viewModel.task == reconciled)
        #expect(!viewModel.reopenFailed)
        #expect(viewModel.missionReopenPrompt == nil)
    }

    @Test("A generic reopen failure offers a retry banner instead of silently reconciling")
    func genericReopenFailureShowsRetryBanner() async {
        let task = fixture(status: .completed)
        let repository = TaskRepositorySpy(taskResult: .success(task), reopenResult: .failure(TaskError.unavailable))
        let viewModel = makeViewModel(taskID: task.id, repository: repository)
        await viewModel.load()

        await viewModel.requestReopen()

        #expect(viewModel.reopenFailed)
        #expect(!viewModel.showReopenSuccessBanner)
    }

    @Test("CA-04 Kids reopens their own completed task")
    func kidsReopensOwnTask() async {
        let task = fixture(status: .completed, assigneeIDs: [Self.kidMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, role: .kid, currentMemberID: Self.kidMemberID, repository: repository)
        await viewModel.load()

        #expect(viewModel.canReopen)
    }

    @Test("CA-05 Kids never sees Reabrir on a task that isn't their own, even when shared with an adult")
    func kidsCannotReopenThirdPartyTask() async {
        let task = fixture(status: .completed, assigneeIDs: [Self.adultMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(taskID: task.id, role: .kid, currentMemberID: Self.kidMemberID, repository: repository)
        await viewModel.load()

        #expect(!viewModel.canReopen)
        await viewModel.requestReopen()
        #expect(repository.reopenCalls.isEmpty, "a hidden action must never reach the server")
    }
}
