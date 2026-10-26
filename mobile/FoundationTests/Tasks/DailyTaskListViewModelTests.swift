import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-009 Fase 1 for TEL-010/TEL-040: CA-01 to CA-04, CA-09, CA-11.
@MainActor
struct DailyTaskListViewModelTests {
    private static let fixedToday = Date(timeIntervalSince1970: 1_760_000_000) // 2025-10-09, arbitrary but stable
    private static let familyCreatedAt = "2020-01-01"

    private func makeViewModel(
        audience: TaskAudience = .adult,
        role: MemberRole = .administrator,
        currentMemberID: UUID = UUID(),
        familyRepository: (any FamilyRepository)? = nil,
        repository: TaskRepositorySpy,
        today: @escaping () -> Date = { Self.fixedToday }
    ) -> DailyTaskListViewModel {
        DailyTaskListViewModel(
            audience: audience,
            role: audience == .kid ? .kid : role,
            currentMemberID: currentMemberID,
            repository: repository,
            familyRepository: familyRepository,
            accessToken: "access-1",
            today: today
        )
    }

    private func task(status: TaskStatus, assignees: [UUID] = []) -> FamilyTask {
        let original = TaskRepositorySpy.fixture
        return FamilyTask(
            id: original.id, title: original.title, weight: original.weight,
            scheduledDate: original.scheduledDate, assigneeIDs: assignees,
            note: original.note, status: status, routineID: original.routineID,
            createdAt: original.createdAt
        )
    }

    private func page(_ task: FamilyTask, displayStatus: TaskStatus? = nil) -> OwnTaskPage {
        OwnTaskPage(items: [OwnTaskListItem(task: task, displayStatus: displayStatus ?? task.status)],
                    nextCursor: nil, familyCreatedAt: Self.familyCreatedAt)
    }

    private func waitForAction(_ viewModel: DailyTaskListViewModel, taskID: UUID) async {
        for _ in 0..<1_000 {
            if !viewModel.actionInFlight.contains(taskID) { return }
            await Task.yield()
        }
        Issue.record("Task action did not finish")
    }

    @Test("SPEC-010 CA-01 and SPEC-011 CA-01: list toggle completes, reopens, and refreshes progress")
    func toggleUpdatesTaskAndProgress() async {
        let pending = task(status: .pending)
        let completed = task(status: .completed)
        let repository = TaskRepositorySpy(
            completeResult: .success(completed), dailyTasksResult: .success(page(pending)),
            dailyProgressResult: .success(DailyProgress(total: 1, completed: 0, percentage: 0, familyCreatedAt: Self.familyCreatedAt)),
            reopenResult: .success(pending)
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        repository.setDailyResults(
            tasks: .success(page(completed)),
            progress: .success(DailyProgress(total: 1, completed: 1, percentage: 100, familyCreatedAt: Self.familyCreatedAt))
        )
        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .completed, "The row changes before the server replies")
        #expect(viewModel.progress?.completed == 1)
        await waitForAction(viewModel, taskID: pending.id)
        #expect(repository.completeCalls == [pending.id])
        #expect(viewModel.items[0].task.status == .completed)
        #expect(viewModel.progress?.completed == 1)

        repository.setDailyResults(
            tasks: .success(page(pending)),
            progress: .success(DailyProgress(total: 1, completed: 0, percentage: 0, familyCreatedAt: Self.familyCreatedAt))
        )
        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.progress?.completed == 0)
        await waitForAction(viewModel, taskID: pending.id)
        #expect(repository.reopenCalls == [ReopenCall(id: pending.id, confirm: false)])
        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.progress?.completed == 0)
    }

    @Test("SPEC-010 CA-04: Member cannot complete a Kids task even when its display status is pending")
    func memberCannotCompleteKidsTaskFromList() async {
        let kidID = UUID()
        let awaiting = task(status: .awaitingConfirmation, assignees: [kidID])
        let repository = TaskRepositorySpy(dailyTasksResult: .success(page(awaiting, displayStatus: .pending)))
        let family = FamilyMembersStub(members: [FamilyMember(id: kidID, name: "Rafa", role: .kid, isFamilyCreator: false)])
        let viewModel = makeViewModel(role: .member, familyRepository: family, repository: repository)
        await viewModel.load()

        #expect(!viewModel.showsToggle(viewModel.items[0]))
        viewModel.toggle(viewModel.items[0])
        #expect(repository.completeCalls.isEmpty)
    }

    @Test("SPEC-010 CA-06/08: uncertain completion is read before another explicit command")
    func uncertainCompletionReconcilesWithoutReplay() async {
        let pending = task(status: .pending)
        let completed = task(status: .completed)
        let repository = TaskRepositorySpy(
            taskResult: .success(completed), completeResult: .failure(TaskError.uncertainOutcome),
            dailyTasksResult: .success(page(pending))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        repository.setDailyResults(tasks: .success(page(completed)))

        viewModel.toggle(viewModel.items[0])
        await waitForAction(viewModel, taskID: pending.id)

        #expect(repository.completeCalls == [pending.id])
        #expect(repository.taskCalls == [pending.id])
        #expect(viewModel.items[0].task.status == .completed)
        #expect(viewModel.actionFailure == nil)
    }

    @Test("SPEC-011 CA-02/03: mission impact requires an explicit second command")
    func missionReopenRequiresConfirmation() async {
        let completed = task(status: .completed)
        let pending = task(status: .pending)
        let affected = [AffectedMission(id: UUID(), title: "Missão")]
        let repository = TaskRepositorySpy(
            dailyTasksResult: .success(page(completed)),
            reopenResult: .failure(TaskError.missionReopenRequiresConfirmation(missionsAffected: affected, hasAcceptedReward: false))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .pending)
        await waitForAction(viewModel, taskID: completed.id)
        #expect(viewModel.missionReopenPrompt == MissionReopenPrompt(missionsAffected: affected, hasAcceptedReward: false))
        #expect(viewModel.items[0].task.status == .completed, "MOD-006 restores the confirmed state until consent")
        #expect(repository.reopenCalls == [ReopenCall(id: completed.id, confirm: false)])

        repository.setReopenResult(.success(pending))
        repository.setDailyResults(tasks: .success(page(pending)))
        viewModel.confirmMissionReopen()
        await waitForAction(viewModel, taskID: completed.id)
        #expect(repository.reopenCalls == [ReopenCall(id: completed.id, confirm: false), ReopenCall(id: completed.id, confirm: true)])
        #expect(viewModel.missionReopenPrompt == nil)
        #expect(viewModel.items[0].task.status == .pending)
    }

    @Test("SPEC-010/011: a second tap keeps the latest intent while the first write is in flight")
    func latestIntentWinsAfterInFlightCompletion() async {
        let pending = task(status: .pending)
        let completed = task(status: .completed)
        let gate = TaskRequestGate()
        let repository = TaskRepositorySpy(
            completeResult: .success(completed), dailyTasksResult: .success(page(pending)),
            dailyProgressResult: .success(DailyProgress(total: 1, completed: 0, percentage: 0, familyCreatedAt: Self.familyCreatedAt)),
            reopenResult: .success(pending), completionGate: gate
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .completed)
        #expect(viewModel.progress?.completed == 1)
        for _ in 0..<1_000 where repository.completeCalls.isEmpty { await Task.yield() }
        #expect(repository.completeCalls.count == 1)

        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.progress?.completed == 0)
        await gate.release()
        await waitForAction(viewModel, taskID: pending.id)

        #expect(repository.completeCalls == [pending.id])
        #expect(repository.reopenCalls == [ReopenCall(id: pending.id, confirm: false)])
        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.actionAlert == nil)
    }

    @Test("SPEC-010 CA-08: a rejected write rolls the optimistic row and progress back")
    func rejectedCompletionRollsBackAndAlerts() async {
        let pending = task(status: .pending)
        let repository = TaskRepositorySpy(
            taskResult: .success(pending), completeResult: .failure(TaskError.actionNotAllowed),
            dailyTasksResult: .success(page(pending)),
            dailyProgressResult: .success(DailyProgress(total: 1, completed: 0, percentage: 0, familyCreatedAt: Self.familyCreatedAt))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        viewModel.toggle(viewModel.items[0])
        #expect(viewModel.items[0].task.status == .completed)
        await waitForAction(viewModel, taskID: pending.id)

        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.progress?.completed == 0)
        #expect(viewModel.actionAlert == .failed)
        #expect(repository.completeCalls == [pending.id])
    }

    @Test("SPEC-010 CA-08: an unreadable outcome never automatically replays the POST")
    func uncertainCompletionBlocksUntilCanonicalRefresh() async {
        let pending = task(status: .pending)
        let repository = TaskRepositorySpy(
            taskResult: .failure(TaskError.network), completeResult: .failure(TaskError.uncertainOutcome),
            dailyTasksResult: .success(page(pending))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        viewModel.toggle(viewModel.items[0])
        await waitForAction(viewModel, taskID: pending.id)

        #expect(viewModel.items[0].task.status == .pending)
        #expect(viewModel.actionAlert == .uncertain)
        #expect(!viewModel.canToggle(viewModel.items[0]))
        #expect(repository.completeCalls == [pending.id])
    }

    @Test("CA-01 loads the day's tasks and progress on first appearance")
    func loadsDailyTasksAndProgress() async {
        let page = OwnTaskPage(
            items: [OwnTaskListItem(task: TaskRepositorySpy.fixture, displayStatus: .pending)],
            nextCursor: nil,
            familyCreatedAt: Self.familyCreatedAt
        )
        let progress = DailyProgress(total: 3, completed: 1, percentage: 100.0 / 3, familyCreatedAt: Self.familyCreatedAt)
        let repository = TaskRepositorySpy(dailyTasksResult: .success(page), dailyProgressResult: .success(progress))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.items == page.items)
        #expect(viewModel.progress == progress)
        #expect(!viewModel.loadFailed)
        #expect(!viewModel.isEmpty)
    }

    @Test("CA-03 a day with no tasks is empty, not a fictional percentage")
    func emptyDayShowsNoFictionalPercentage() async {
        let progress = DailyProgress(total: 0, completed: 0, percentage: nil, familyCreatedAt: Self.familyCreatedAt)
        let repository = TaskRepositorySpy(
            dailyTasksResult: .success(OwnTaskPage(items: [], nextCursor: nil, familyCreatedAt: Self.familyCreatedAt)),
            dailyProgressResult: .success(progress)
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.progress?.percentage == nil)
    }

    @Test("CA-09 a failed first load never presents as the empty state")
    func firstLoadFailureIsNotPresentedAsEmpty() async {
        let repository = TaskRepositorySpy(
            dailyTasksResult: .failure(TaskError.unavailable),
            dailyProgressResult: .failure(TaskError.unavailable)
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.items.isEmpty)
        #expect(!viewModel.isEmpty, "loadFailed must take precedence over the empty state (UX-009 §3)")
    }

    @Test("CA-09 a failed reload keeps the last known list and progress instead of clearing them")
    func reloadFailureKeepsLastKnownState() async {
        let page = OwnTaskPage(
            items: [OwnTaskListItem(task: TaskRepositorySpy.fixture, displayStatus: .pending)],
            nextCursor: nil,
            familyCreatedAt: Self.familyCreatedAt
        )
        let progress = DailyProgress(total: 2, completed: 1, percentage: 50, familyCreatedAt: Self.familyCreatedAt)
        let repository = TaskRepositorySpy(dailyTasksResult: .success(page), dailyProgressResult: .success(progress))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        #expect(!viewModel.loadFailed)

        repository.setDailyResults(tasks: .failure(TaskError.unavailable), progress: .failure(TaskError.unavailable))
        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.items == page.items, "a failed refresh must not clear the previously shown tasks")
        #expect(viewModel.progress == progress, "a failed refresh must not zero the previously shown progress")
    }

    @Test("CA-11 the label reflects the backend-provided displayStatus, never the effective status")
    func labelReflectsDisplayStatusNotEffectiveStatus() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)

        let adultView = OwnTaskListItem(task: TaskRepositorySpy.fixture, displayStatus: .pending)
        let kidsView = OwnTaskListItem(task: TaskRepositorySpy.fixture, displayStatus: .awaitingConfirmation)

        #expect(viewModel.displayStatusLabel(for: adultView) == "tasks.personal.status.pending")
        #expect(viewModel.displayStatusLabel(for: kidsView) == "tasks.personal.status.awaitingConfirmation")
    }

    @Test("RN49 blocks dates after the last day of the current month")
    func rn49BlocksDatesAfterCurrentMonth() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)

        let withinMonth = calendar.date(byAdding: .day, value: 1, to: Self.fixedToday)!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: Self.fixedToday)!

        #expect(viewModel.isDateAvailable(withinMonth))
        #expect(!viewModel.isDateAvailable(nextMonth))
    }

    @Test("SPEC-009 E-05: before the first load the lower bound is unknown, so no past date is blocked yet")
    func lowerBoundUnknownBeforeFirstLoad() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let longAgo = calendar.date(byAdding: .year, value: -10, to: Self.fixedToday)!

        #expect(viewModel.isDateAvailable(longAgo))
    }

    @Test("RN49 blocks dates before the family's creation date, once learned from a successful load")
    func rn49BlocksDatesBeforeFamilyCreation() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let creationDay = calendar.date(byAdding: .day, value: -5, to: Self.fixedToday)!
        let dayBeforeCreation = calendar.date(byAdding: .day, value: -1, to: creationDay)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let familyCreatedAt = formatter.string(from: creationDay)

        let page = OwnTaskPage(items: [], nextCursor: nil, familyCreatedAt: familyCreatedAt)
        let progress = DailyProgress(total: 0, completed: 0, percentage: nil, familyCreatedAt: familyCreatedAt)
        let repository = TaskRepositorySpy(dailyTasksResult: .success(page), dailyProgressResult: .success(progress))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()

        #expect(!viewModel.isDateAvailable(dayBeforeCreation))
        #expect(viewModel.isDateAvailable(creationDay))
    }

    @Test("CA-02 selecting an available date reloads only that day; an unavailable one is a no-op")
    func selectingDateReloadsOnlyWhenAvailable() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: Self.fixedToday)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Self.fixedToday)!

        await viewModel.selectDate(nextMonth)
        #expect(viewModel.selectedDate == calendar.startOfDay(for: Self.fixedToday))
        #expect(repository.dailyTasksCalls.isEmpty, "an out-of-range selection must never trigger a query (CA-03)")

        await viewModel.selectDate(tomorrow)
        #expect(viewModel.selectedDate == calendar.startOfDay(for: tomorrow))
        #expect(repository.dailyTasksCalls.count == 1)
    }

    @Test("Reloading preserves the currently selected date")
    func reloadPreservesSelectedDate() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Self.fixedToday)!

        await viewModel.selectDate(tomorrow)
        await viewModel.load()

        #expect(viewModel.selectedDate == calendar.startOfDay(for: tomorrow))
    }
}
