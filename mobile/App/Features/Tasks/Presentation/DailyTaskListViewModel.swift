import Observation
import SwiftUI

/// Who the checklist belongs to. The backend already projects `displayStatus` per actor role
/// (SPEC-009 §5), so this only toggles presentation differences that aren't in the DTO: whether
/// "Nova tarefa" is offered and whether a row opens TEL-012 (UX-009 doesn't define a Kids-side
/// task detail destination, so Kids rows stay informational — see RT: TEL-041 isn't in scope).
enum TaskAudience: Equatable, Sendable {
    case adult
    case kid
}

/// Backs TEL-010/TEL-040 (SPEC-009 Fase 1 — own daily checklist, both profiles).
@MainActor
@Observable
final class DailyTaskListViewModel {
    let audience: TaskAudience
    private let getDailyTasks: GetDailyTasksUseCase
    private let getDailyProgress: GetDailyProgressUseCase
    private let accessToken: String
    private let today: () -> Date
    private let calendar: Calendar

    private(set) var selectedDate: Date
    private(set) var items: [OwnTaskListItem] = []
    private(set) var progress: DailyProgress?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// RN49's lower bound (SPEC-009 E-05), learned from the first successful load. `nil` until
    /// then: with no loaded value yet, no past date is speculatively blocked.
    private(set) var familyCreatedAt: Date?

    init(
        audience: TaskAudience,
        repository: any TaskRepository,
        accessToken: String,
        today: @escaping () -> Date = Date.init
    ) {
        self.audience = audience
        self.getDailyTasks = GetDailyTasksUseCase(repository: repository)
        self.getDailyProgress = GetDailyProgressUseCase(repository: repository)
        self.accessToken = accessToken
        self.today = today
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar
        self.selectedDate = calendar.startOfDay(for: today())
    }

    var isEmpty: Bool {
        !isLoading && !loadFailed && items.isEmpty
    }

    /// RN49: between the family's creation date and the last day of the current month, both
    /// inclusive (SPEC-009 E-05). The lower bound is only known after a successful load — until
    /// then, no past date is speculatively blocked (there is nothing to compare against yet).
    func isDateAvailable(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day <= Self.endOfCurrentMonth(from: today(), calendar: calendar) else {
            return false
        }
        guard let familyCreatedAt else {
            return true
        }
        return day >= familyCreatedAt
    }

    /// Call on first appearance and from the error state's retry action. Never clears already
    /// shown data on failure (CA-09): a background refresh failing keeps the last known list and
    /// progress visible with a non-blocking banner, rather than flashing an empty/zeroed state.
    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        let referenceDate = Self.wireString(from: selectedDate)
        do {
            async let tasksResult = getDailyTasks.execute(referenceDate: referenceDate, cursor: nil, accessToken: accessToken)
            async let progressResult = getDailyProgress.execute(referenceDate: referenceDate, accessToken: accessToken)
            let (page, progress) = try await (tasksResult, progressResult)
            items = page.items
            self.progress = progress
            familyCreatedAt = Self.date(fromWire: page.familyCreatedAt) ?? familyCreatedAt
        } catch {
            loadFailed = true
        }
    }

    /// Selecting an unavailable date is a no-op (CA-03): it never triggers a query.
    func selectDate(_ date: Date) async {
        let normalized = calendar.startOfDay(for: date)
        guard isDateAvailable(normalized), normalized != selectedDate else {
            return
        }
        selectedDate = normalized
        items = []
        progress = nil
        await load()
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: today())
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func displayStatusLabel(for item: OwnTaskListItem) -> LocalizedStringKey {
        switch item.displayStatus {
        case .pending: "tasks.personal.status.pending"
        case .awaitingConfirmation: "tasks.personal.status.awaitingConfirmation"
        case .completed: "tasks.detail.status_completed"
        }
    }

    private static func endOfCurrentMonth(from today: Date, calendar: Calendar) -> Date {
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let lastDay = calendar.date(bySetting: .day, value: range.upperBound - 1, of: today) else {
            return today
        }
        return calendar.startOfDay(for: lastDay)
    }

    private static func wireString(from date: Date) -> String {
        Self.wireFormatter.string(from: date)
    }

    private static func date(fromWire wire: String) -> Date? {
        Self.wireFormatter.date(from: wire)
    }

    private static var wireFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
