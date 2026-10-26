import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-007 Mobile CAs for TEL-012: CA-05 to CA-08, CA-15.
/// SPEC-008 Mobile CA-06 for routine occurrences.
/// SPEC-011 Mobile CAs for the Reabrir action: CA-01 to CA-05.
/// SPEC-010 Fase 2 CA-01/02/04/05/06 for direct completion and reconciliation.
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
        repository: TaskRepositorySpy,
        routineRepository: any RoutineRepository = RoutineRepositorySpy(),
        familyRepository: any FamilyRepository = FamilyMembersStub()
    ) -> TaskDetailViewModel {
        TaskDetailViewModel(
            taskID: taskID,
            role: role,
            currentMemberID: currentMemberID,
            repository: repository,
            routineRepository: routineRepository,
            familyRepository: familyRepository,
            accessToken: "access-1"
        )
    }

    @Test("SPEC-008 CA-06: an occurrence keeps its own task state while the routine exposes pending materialization")
    func loadsRoutineWithoutChangingOccurrence() async {
        let base = fixture(status: .pending)
        let task = FamilyTask(
            id: base.id, title: base.title, weight: base.weight, scheduledDate: base.scheduledDate,
            assigneeIDs: base.assigneeIDs, note: base.note, status: base.status,
            routineID: routineRepositorySpyFixture.id, createdAt: base.createdAt
        )
        let taskRepository = TaskRepositorySpy(taskResult: .success(task))
        let routineRepository = RoutineRepositorySpy()
        let viewModel = makeViewModel(taskID: task.id, repository: taskRepository, routineRepository: routineRepository)

        await viewModel.load()

        #expect(viewModel.task?.id == task.id)
        #expect(viewModel.task?.status == .pending)
        #expect(viewModel.routine?.materializationState == .pending)
        #expect(routineRepository.getCalls == [routineRepositorySpyFixture.id])
    }

    @Test("SPEC-008 CA-03 / SPEC-011 CA-04: Kids can reopen their own occurrence without loading routine configuration")
    func kidReopensOwnRoutineOccurrenceWithoutRoutineAccess() async {
        let base = fixture(status: .completed, assigneeIDs: [Self.kidMemberID])
        let task = FamilyTask(
            id: base.id, title: base.title, weight: base.weight, scheduledDate: base.scheduledDate,
            assigneeIDs: base.assigneeIDs, note: base.note, status: base.status,
            routineID: routineRepositorySpyFixture.id, createdAt: base.createdAt
        )
        let taskRepository = TaskRepositorySpy(taskResult: .success(task))
        let routineRepository = RoutineRepositorySpy()
        let viewModel = makeViewModel(
            taskID: task.id,
            role: .kid,
            currentMemberID: Self.kidMemberID,
            repository: taskRepository,
            routineRepository: routineRepository
        )

        await viewModel.load()

        #expect(viewModel.canReopen)
        #expect(viewModel.routine == nil)
        #expect(routineRepository.getCalls.isEmpty)
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

    @Test("SPEC-010 CA-01/05: Admin completes a Kids signal and uses the canonical result")
    func adminCompletesAwaitingKidsTask() async {
        let pending = fixture(status: .awaitingConfirmation, assigneeIDs: [Self.kidMemberID])
        let completed = fixture(status: .completed, assigneeIDs: [Self.kidMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(pending), completeResult: .success(completed))
        let viewModel = makeViewModel(taskID: pending.id, repository: repository)
        await viewModel.load()

        #expect(viewModel.canComplete)
        await viewModel.requestComplete()

        #expect(viewModel.task == completed)
        #expect(viewModel.completionRevision == 1)
        #expect(repository.completeCalls == [pending.id])
    }

    @Test("SPEC-010 CA-02: an unassigned task displays the assignee returned by the server")
    func unassignedTaskUsesServerAssignee() async {
        let pending = fixture(status: .pending)
        let completed = fixture(status: .completed, assigneeIDs: [Self.adultMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(pending), completeResult: .success(completed))
        let viewModel = makeViewModel(taskID: pending.id, repository: repository)
        await viewModel.load()
        await viewModel.requestComplete()

        #expect(viewModel.task?.assigneeIDs == [Self.adultMemberID])
        #expect(viewModel.task?.status == .completed)
    }

    @Test("TEL-012: a previous reopening banner disappears when the task is completed again")
    func completionClearsReopeningBanner() async {
        let completed = fixture(status: .completed)
        let pending = fixture(status: .pending)
        let repository = TaskRepositorySpy(
            taskResult: .success(completed),
            completeResult: .success(completed),
            reopenResult: .success(pending)
        )
        let viewModel = makeViewModel(taskID: completed.id, repository: repository)
        await viewModel.load()

        await viewModel.requestReopen()
        #expect(viewModel.showReopenSuccessBanner)

        await viewModel.requestComplete()
        #expect(viewModel.task?.status == .completed)
        #expect(!viewModel.showReopenSuccessBanner)
    }

    @Test("SPEC-010 CA-04: a Member never sees or invokes completion on a Kids task")
    func memberCannotCompleteKidsTask() async {
        let pending = fixture(status: .pending, assigneeIDs: [Self.kidMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(pending))
        let family = FamilyMembersStub(members: [
            FamilyMember(id: Self.kidMemberID, name: "Rafa", role: .kid, isFamilyCreator: false)
        ])
        let viewModel = makeViewModel(taskID: pending.id, role: .member, repository: repository, familyRepository: family)
        await viewModel.load()

        #expect(!viewModel.showsCompleteAction)
        await viewModel.requestComplete()
        #expect(repository.completeCalls.isEmpty)
    }

    @Test("SPEC-010 CA-04: Member checks every page before enabling an adult-assigned task")
    func memberChecksPagedAssignees() async {
        let pending = fixture(status: .pending, assigneeIDs: [Self.adultMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(pending))
        let family = FamilyMembersStub(pages: [
            [FamilyMember(id: Self.kidMemberID, name: "Rafa", role: .kid, isFamilyCreator: false)],
            [FamilyMember(id: Self.adultMemberID, name: "Alex", role: .member, isFamilyCreator: false)]
        ])
        let viewModel = makeViewModel(taskID: pending.id, role: .member, repository: repository, familyRepository: family)
        await viewModel.load()

        #expect(viewModel.showsCompleteAction)
        #expect(!viewModel.memberRolesLoadFailed)
    }

    @Test("SPEC-010 CA-04: unavailable member roles keep the action hidden")
    func memberRoleLookupFailureHidesCompletion() async {
        let pending = fixture(status: .pending, assigneeIDs: [Self.kidMemberID])
        let repository = TaskRepositorySpy(taskResult: .success(pending))
        let family = FamilyMembersStub(listError: .unavailable)
        let viewModel = makeViewModel(taskID: pending.id, role: .member, repository: repository, familyRepository: family)
        await viewModel.load()

        #expect(!viewModel.showsCompleteAction)
        #expect(viewModel.memberRolesLoadFailed)
    }

    @Test("SPEC-010 CA-06: TASK_ALREADY_COMPLETED silently loads the confirmed state once")
    func completionConflictReconciles() async {
        let pending = fixture(status: .pending)
        let completed = fixture(status: .completed)
        let repository = TaskRepositorySpy(taskResult: .success(pending), completeResult: .failure(TaskError.alreadyCompleted))
        let viewModel = makeViewModel(taskID: pending.id, repository: repository)
        await viewModel.load()
        repository.setTaskResult(.success(completed))

        await viewModel.requestComplete()

        #expect(viewModel.task == completed)
        #expect(viewModel.completionFailure == nil)
        #expect(viewModel.completionRevision == 1)
        #expect(repository.completeCalls == [pending.id])
        #expect(repository.taskCalls == [pending.id, pending.id])
    }

    @Test("SPEC-010 safety: an uncertain completion checks state and never resends automatically")
    func uncertainCompletionChecksBeforeAnotherAction() async {
        let pending = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(pending), completeResult: .failure(TaskError.uncertainOutcome))
        let viewModel = makeViewModel(taskID: pending.id, repository: repository)
        await viewModel.load()

        await viewModel.requestComplete()

        #expect(viewModel.task?.status == .pending)
        #expect(viewModel.completionFailure == .notCompleted)
        #expect(viewModel.completionRevision == 0)
        #expect(repository.completeCalls == [pending.id])
        #expect(repository.taskCalls == [pending.id, pending.id])
    }

    @Test("SPEC-010 safety: failed reconciliation blocks a second POST until refresh succeeds")
    func failedReconciliationBlocksSecondPost() async {
        let pending = fixture(status: .pending)
        let repository = TaskRepositorySpy(taskResult: .success(pending), completeResult: .failure(TaskError.uncertainOutcome))
        let viewModel = makeViewModel(taskID: pending.id, repository: repository)
        await viewModel.load()
        repository.setTaskResult(.failure(TaskError.network))

        await viewModel.requestComplete()
        await viewModel.requestComplete()

        #expect(viewModel.completionFailure == .needsRefresh)
        #expect(repository.completeCalls == [pending.id])
        repository.setTaskResult(.success(pending))
        await viewModel.refreshCompletionStatus()
        #expect(viewModel.completionFailure == .notCompleted)
        #expect(viewModel.canComplete)
        #expect(repository.completeCalls == [pending.id])
    }
}
