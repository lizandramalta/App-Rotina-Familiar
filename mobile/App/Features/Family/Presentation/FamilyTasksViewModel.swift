import Foundation
import Observation

/// TEL-011 and TEL-032 share a confirmed interval; role projection remains on the server.
@MainActor
@Observable
final class FamilyTasksViewModel {
    private(set) var range: FamilyDateRange
    let isMemberDetail: Bool
    private(set) var selectedMemberID: UUID?
    let members: [FamilyMemberProgress]
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

    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?
    private var revision = 0

    init(
        range: FamilyDateRange,
        memberID: UUID?,
        members: [FamilyMemberProgress] = [],
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

    func makeReportView() -> FamilyWeeklyReportView? {
        guard !isMemberDetail, let familyCreatedAt, let token = accessTokenProvider() else { return nil }
        return FamilyWeeklyReportView(
            range: range, familyCreatedAt: familyCreatedAt, familyName: familyName,
            timeZoneID: timeZoneID, repository: familyRepository, accessToken: token
        )
    }

    func applyStatus(_ value: FamilyTaskStatusFilter) async {
        guard availableStatuses.contains(value), status != value else { return }
        status = value
        await load()
    }

    func applyMember(_ memberID: UUID?) async {
        guard !members.isEmpty, memberID == nil || members.contains(where: { $0.memberID == memberID }) else { return }
        guard selectedMemberID != memberID else { return }
        selectedMemberID = memberID
        await load()
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
            let page = try await familyRepository.listFamilyTasks(
                range: range,
                memberID: selectedMemberID,
                status: requestedStatus,
                cursor: nil,
                accessToken: token
            )
            guard revision == requestedRevision else { return }
            items = page.items
            nextCursor = page.nextCursor
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
