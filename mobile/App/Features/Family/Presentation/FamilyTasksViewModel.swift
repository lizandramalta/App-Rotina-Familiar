import Foundation
import Observation

/// TEL-011 queries a selected interval; TEL-032 uses a single family-local day.
@MainActor
@Observable
final class FamilyTasksViewModel {
    private(set) var range: FamilyDateRange
    let isMemberDetail: Bool
    private(set) var selectedMemberID: UUID?
    private(set) var members: [FamilyMemberProgress]
    let currentMemberID: UUID?
    let role: MemberRole
    let familyName: String
    let familyCreatedAt: String?
    let timeZoneID: String
    private(set) var items: [FamilyTaskItem] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var failed = false
    private(set) var loadMoreFailed = false
    private(set) var status: FamilyTaskStatusFilter = .all
    private(set) var progress: FamilyProgress?

    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?
    private var revision = 0

    init(
        range: FamilyDateRange,
        memberID: UUID?,
        members: [FamilyMemberProgress] = [],
        currentMemberID: UUID? = nil,
        role: MemberRole,
        familyName: String = "",
        familyCreatedAt: String? = nil,
        timeZoneID: String = FamilyCreationValidation.defaultTimeZoneID,
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?
    ) {
        self.range = range
        self.isMemberDetail = memberID != nil
        self.selectedMemberID = memberID
        self.members = members
        self.currentMemberID = currentMemberID
        self.role = role
        self.familyName = familyName
        self.familyCreatedAt = familyCreatedAt
        self.timeZoneID = timeZoneID
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
    }

    var availableStatuses: [FamilyTaskStatusFilter] {
        role == .administrator
            ? [.all, .pending, .awaitingConfirmation, .completed]
            : [.all, .pending, .completed]
    }

    func applyRange(_ newRange: FamilyDateRange) async {
        guard newRange.startDate <= newRange.endDate,
              familyCreatedAt.map({ newRange.startDate >= $0 }) ?? true else { return }
        let previousRange = range
        range = newRange
        await load()
        if failed { range = previousRange }
    }

    /// SPEC-009 CA-06/07/12: date and status are one filter confirmation in TEL-011.
    func applyFilters(range newRange: FamilyDateRange, status newStatus: FamilyTaskStatusFilter) async {
        guard availableStatuses.contains(newStatus),
              newRange.startDate <= newRange.endDate,
              familyCreatedAt.map({ newRange.startDate >= $0 }) ?? true else { return }
        let previousRange = range
        let previousStatus = status
        range = newRange
        status = newStatus
        await load()
        if failed {
            range = previousRange
            status = previousStatus
        }
    }

    func count(for filter: FamilyTaskStatusFilter) -> Int? {
        guard let progress else { return nil }
        return Self.count(for: filter, in: progress)
    }

    func previewCount(range: FamilyDateRange, status: FamilyTaskStatusFilter) async throws -> Int? {
        guard let token = accessTokenProvider() else { throw FamilyError.unavailable }
        let overview = try await familyRepository.getFamilyOverview(range: range, accessToken: token)
        guard let progress = progress(in: overview) else { return nil }
        return Self.count(for: status, in: progress)
    }

    private func progress(in overview: FamilyOverview) -> FamilyProgress? {
        guard let selectedMemberID else { return overview.progress }
        return overview.members.first(where: { $0.memberID == selectedMemberID })?.progress
    }

    private static func count(for filter: FamilyTaskStatusFilter, in progress: FamilyProgress) -> Int {
        switch filter {
        case .all: progress.total
        case .pending: progress.pending
        case .awaitingConfirmation: progress.awaitingConfirmation
        case .completed: progress.completed
        }
    }

    func makeReportView() -> FamilyWeeklyReportView? {
        guard !isMemberDetail, let familyCreatedAt, let token = accessTokenProvider() else { return nil }
        return FamilyWeeklyReportView(
            range: range, familyCreatedAt: familyCreatedAt, familyName: familyName,
            timeZoneID: timeZoneID, repository: familyRepository, accessToken: token
        )
    }

    var reportSpansMultipleWeeks: Bool {
        guard let start = civilDate(range.startDate),
              let end = civilDate(range.endDate) else { return false }
        return weekStart(for: start) != weekStart(for: end)
    }

    /// SPEC-019 CA-05–07: a single selected week opens the native share sheet directly.
    func generateCurrentWeekReport() async throws -> URL {
        guard !isMemberDetail, !reportSpansMultipleWeeks,
              let token = accessTokenProvider() else { throw FamilyError.unavailable }
        let snapshot = try await familyRepository.getWeeklyReport(
            referenceDate: range.startDate, accessToken: token
        )
        let data = FamilyPDFRenderer.render(snapshot: snapshot, familyName: familyName)
        let file = FileManager.default.temporaryDirectory
            .appending(path: "family-report-\(UUID().uuidString).pdf")
        try data.write(to: file, options: .atomic)
        return file
    }

    private var reportCalendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return value
    }

    private func civilDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = reportCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = reportCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func weekStart(for date: Date) -> Date {
        let weekday = reportCalendar.component(.weekday, from: date)
        return reportCalendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: date) ?? date
    }

    func applyStatus(_ value: FamilyTaskStatusFilter) async {
        guard availableStatuses.contains(value), status != value else { return }
        let previousStatus = status
        status = value
        await load()
        if failed { status = previousStatus }
    }

    func applyMember(_ memberID: UUID?) async {
        guard !members.isEmpty, memberID == nil || members.contains(where: { $0.memberID == memberID }) else { return }
        guard selectedMemberID != memberID else { return }
        let previousMemberID = selectedMemberID
        selectedMemberID = memberID
        await load()
        if failed { selectedMemberID = previousMemberID }
    }

    func load() async {
        guard let token = accessTokenProvider() else {
            failed = true
            return
        }
        revision += 1
        let requestedRevision = revision
        let requestedStatus = status
        isLoading = true
        failed = false
        defer {
            if revision == requestedRevision { isLoading = false }
        }
        do {
            async let tasks = familyRepository.listFamilyTasks(
                range: range, memberID: selectedMemberID, status: requestedStatus,
                cursor: nil, accessToken: token
            )
            async let totals = familyRepository.getFamilyOverview(range: range, accessToken: token)
            let (page, overview) = try await (tasks, totals)
            guard revision == requestedRevision else { return }
            items = page.items
            nextCursor = page.nextCursor
            members = overview.members
            progress = progress(in: overview)
            loadMoreFailed = false
        } catch FamilyError.actionNotAllowed {
            guard revision == requestedRevision else { return }
            items = []
            nextCursor = nil
            failed = true
        } catch {
            guard revision == requestedRevision else { return }
            failed = true
        }
    }

    func loadMoreIfNeeded(currentItem: FamilyTaskItem) async {
        guard currentItem.id == items.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard let nextCursor, !isLoading, !isLoadingMore, let token = accessTokenProvider() else { return }
        let requestedRevision = revision
        isLoadingMore = true
        loadMoreFailed = false
        defer {
            if revision == requestedRevision { isLoadingMore = false }
        }
        do {
            let page = try await familyRepository.listFamilyTasks(
                range: range,
                memberID: selectedMemberID,
                status: status,
                cursor: nextCursor,
                accessToken: token
            )
            guard revision == requestedRevision else { return }
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            self.nextCursor = page.nextCursor
        } catch {
            guard revision == requestedRevision else { return }
            loadMoreFailed = true
        }
    }
}
