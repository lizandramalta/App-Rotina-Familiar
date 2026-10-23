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
        repository: TaskRepositorySpy,
        today: @escaping () -> Date = { Self.fixedToday }
    ) -> DailyTaskListViewModel {
        DailyTaskListViewModel(audience: audience, repository: repository, accessToken: "access-1", today: today)
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
