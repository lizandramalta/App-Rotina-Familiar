import Foundation
import Observation
import SwiftUI

/// TEL-050 — Família (SPEC-003 Phase 1, UX-003 §5.1). Paginated member list plus the Admin-only entry to TEL-033.
@MainActor
@Observable
final class FamilyOverviewViewModel {
    enum KidsNameUpdateResult { case saved, failed, reconciliationRequired, noLongerEligible }
    private(set) var members: [FamilyMember] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var loadFailed = false
    private(set) var loadMoreFailed = false
    private(set) var familyName = ""
    private(set) var timeZoneID = FamilyCreationValidation.defaultTimeZoneID
    private(set) var overview: FamilyOverview?
    private(set) var todayOverview: FamilyOverview?
    private(set) var applauseSummary: [UUID: FamilyApplauseSummary] = [:]
    private(set) var sendingApplauseIDs: Set<UUID> = []
    private(set) var sentApplauseIDs: Set<UUID> = []
    private(set) var applauseFailed = false
    private(set) var isLoadingOverview = false
    private(set) var overviewFailed = false
    private(set) var selectedRange: FamilyDateRange?

    private let session: ActiveFamilySession
    private let familyRepository: any FamilyRepository
    /// Synchronous token read handed to child screens; kept fresh by the session store.
    private let accessTokenProvider: @MainActor () -> String?
    private let validAccessToken: AccessTokenProvider?
    private let makeKidsReviewQueueViewModel: (() -> KidsReviewQueueViewModel)?

    init(
        session: ActiveFamilySession,
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?,
        validAccessToken: AccessTokenProvider? = nil,
        makeKidsReviewQueueViewModel: (() -> KidsReviewQueueViewModel)? = nil
    ) {
        self.makeKidsReviewQueueViewModel = makeKidsReviewQueueViewModel
        self.session = session
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
        self.validAccessToken = validAccessToken
    }

    private func currentToken(forceRefresh: Bool = false) async -> String? {
        guard let validAccessToken else { return accessTokenProvider() }
        return try? await validAccessToken(forceRefresh)
    }

    /// The server stays the authority (RNF07); this only hides controls the API would refuse.
    var canAddMember: Bool { session.role == .administrator }
    var canConfigureFamily: Bool { session.role == .administrator }
    /// Kids confirmations are Admin-only (SPEC-013 CA-05, UX-013 §1).
    var canReviewKidsConfirmations: Bool { session.role == .administrator && makeKidsReviewQueueViewModel != nil }
    var timeZoneDisplayName: String { TimeZoneDisplay.displayName(for: timeZoneID) }
    var currentMemberID: UUID { session.memberID }
    var hasMorePages: Bool { nextCursor != nil }
    var existingMemberIDs: Set<UUID> { Set(members.map(\.id)) }

    var errorMessage: LocalizedStringKey? {
        loadFailed ? "family.overview.error_load" : nil
    }

    /// A failed reload keeps the confirmed members and only reports a non-blocking error.
    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // A 401 surfaces as `rejected`: renew the token once before reporting the failure.
        if await load(forceRefresh: false) == .rejected {
            await load(forceRefresh: true)
        }
    }

    @discardableResult
    private func load(forceRefresh: Bool) async -> FamilyError? {
        loadFailed = false
        guard let token = await currentToken(forceRefresh: forceRefresh) else {
            loadFailed = true
            return nil
        }
        await loadFamilyProfile(token: token)
        await loadOverview(token: token, range: selectedRange)
        await loadTodayOverview(token: token)
        await loadApplauseSummary(token: token)
        do {
            let page = try await familyRepository.listMembers(accessToken: token, cursor: nil)
            members = page.items
            nextCursor = page.nextCursor
            loadMoreFailed = false
            return nil
        } catch FamilyError.actionNotAllowed {
            clearConfirmedMembers()
            loadFailed = true
            return .actionNotAllowed
        } catch {
            // Network/availability failures keep the already confirmed list.
            loadFailed = true
            return error as? FamilyError
        }
    }

    private func loadOverview(token: String, range: FamilyDateRange?) async {
        guard !isLoadingOverview else { return }
        isLoadingOverview = true
        overviewFailed = false
        defer { isLoadingOverview = false }
        do {
            let confirmed = try await familyRepository.getFamilyOverview(range: range, accessToken: token)
            overview = confirmed
            selectedRange = confirmed.range
        } catch FamilyError.actionNotAllowed {
            overview = nil
            overviewFailed = true
        } catch {
            overviewFailed = true
        }
    }

    /// TEL-050 incentive cards use today's progress even when the visible family range is wider.
    private func loadTodayOverview(token: String) async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: .now)
        let todayRange = FamilyDateRange(startDate: today, endDate: today)
        if overview?.range == todayRange {
            todayOverview = overview
            return
        }
        do {
            todayOverview = try await familyRepository.getFamilyOverview(range: todayRange, accessToken: token)
        } catch {
            // The optional cards never present stale eligibility as confirmed data.
            todayOverview = nil
        }
    }

    func applyRange(_ range: FamilyDateRange) async {
        guard range.startDate <= range.endDate,
              let firstDate = overview?.familyCreatedAt,
              range.startDate >= firstDate,
              let token = await currentToken() else { return }
        if range != selectedRange { sentApplauseIDs = [] }
        await loadOverview(token: token, range: range)
        await loadApplauseSummary(token: token)
    }

    func previewTaskCount(for range: FamilyDateRange) async throws -> Int {
        guard let token = await currentToken() else { throw FamilyError.unavailable }
        return try await familyRepository.getFamilyOverview(range: range, accessToken: token).progress.total
    }

    private func loadApplauseSummary(token: String) async {
        guard let range = selectedRange else { return }
        do {
            let items = try await familyRepository.listFamilyApplause(range: range, accessToken: token)
            applauseSummary = Dictionary(uniqueKeysWithValues: items.map { ($0.memberID, $0) })
        } catch {
            applauseSummary = [:]
        }
    }

    func sendApplause(to memberID: UUID) async {
        guard canConfigureFamily, memberID != currentMemberID,
              let range = selectedRange, !sendingApplauseIDs.contains(memberID) else { return }
        sendingApplauseIDs.insert(memberID)
        applauseFailed = false
        defer { sendingApplauseIDs.remove(memberID) }
        guard let token = await currentToken() else {
            applauseFailed = true
            return
        }
        do {
            try await familyRepository.sendFamilyApplause(memberID: memberID, range: range, accessToken: token)
            sentApplauseIDs.insert(memberID)
            await loadApplauseSummary(token: token)
        } catch {
            applauseFailed = true
        }
    }

    func dismissApplauseFailure() { applauseFailed = false }

    /// Name and time zone are confirmed by the server; a failure keeps what is already shown.
    private func loadFamilyProfile(token: String) async {
        do {
            let profile = try await familyRepository.getFamily(accessToken: token)
            familyName = profile.name
            timeZoneID = profile.timeZoneID
        } catch {
            loadFailed = true
        }
    }

    func loadMoreIfNeeded(currentMember: FamilyMember) async {
        guard !loadMoreFailed, currentMember.id == members.last?.id else { return }
        await loadMore()
    }

    /// Also the explicit retry after a failed page (UX-06).
    func loadMore() async {
        guard hasMorePages, !isLoadingMore, !isLoading, let cursor = nextCursor else { return }
        guard let token = await currentToken() else {
            loadMoreFailed = true
            return
        }

        isLoadingMore = true
        loadMoreFailed = false
        defer { isLoadingMore = false }
        do {
            let page = try await familyRepository.listMembers(accessToken: token, cursor: cursor)
            let known = existingMemberIDs
            members += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
        } catch FamilyError.actionNotAllowed {
            clearConfirmedMembers()
            loadFailed = true
        } catch {
            loadMoreFailed = true
        }
    }

    /// Access was refused: members the viewer may no longer see must not stay on screen (CA-03).
    private func clearConfirmedMembers() {
        members = []
        nextCursor = nil
        loadMoreFailed = false
    }

    /// Only the server-confirmed name is shown; an unchanged or empty name sends nothing.
    func updateFamilyName(_ newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != familyName else { return }
        guard let token = await currentToken() else { throw FamilyError.unavailable }
        let updated = try await familyRepository.updateFamilyName(trimmed, accessToken: token)
        familyName = updated.name
        timeZoneID = updated.timeZoneID
    }

    func memberCreated() async {
        await loadInitial()
    }

    /// SPEC-003 CA-02/03/07: only Kids names are corrected here; the server rechecks the role.
    func updateKidsName(memberID: UUID, name: String) async -> KidsNameUpdateResult {
        guard canConfigureFamily,
              let member = members.first(where: { $0.id == memberID }),
              member.role == .kid,
              memberID != currentMemberID,
              let token = await currentToken() else { return .noLongerEligible }
        do {
            let updated = try await familyRepository.updateMemberName(
                memberID: memberID, name: name, accessToken: token
            )
            replaceMember(updated)
            return .saved
        } catch {
            // A lost PATCH response is reconciled before offering another write (CA-07).
            guard let current = await refreshMember(memberID: memberID) else {
                return .reconciliationRequired
            }
            guard current.role == .kid else { return .noLongerEligible }
            return current.name == name ? .saved : .failed
        }
    }

    @discardableResult
    func refreshMember(memberID: UUID) async -> FamilyMemberDetail? {
        guard let token = await currentToken() else { return nil }
        do {
            let current = try await familyRepository.getMemberDetail(memberID: memberID, accessToken: token)
            replaceMember(FamilyMember(
                id: current.id, name: current.name, role: current.role,
                isFamilyCreator: current.isFamilyCreator
            ))
            return current
        } catch { return nil }
    }

    private func replaceMember(_ member: FamilyMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index] = member
    }

    func makeKidsReviewQueue() -> KidsReviewQueueViewModel? {
        makeKidsReviewQueueViewModel?()
    }

    func makeMemberDetailViewModel(memberID: UUID) -> MemberDetailViewModel {
        MemberDetailViewModel(
            memberID: memberID,
            session: session,
            familyRepository: familyRepository,
            accessTokenProvider: accessTokenProvider,
            familyCreatedAt: overview?.familyCreatedAt,
            timeZoneID: timeZoneID
        )
    }

    func makeFamilyTasksViewModel(memberID: UUID? = nil) -> FamilyTasksViewModel? {
        guard let range = selectedRange else { return nil }
        return FamilyTasksViewModel(
            range: range,
            memberID: memberID,
            members: overview?.members ?? [],
            currentMemberID: session.memberID,
            role: session.role,
            familyName: familyName,
            familyCreatedAt: overview?.familyCreatedAt,
            timeZoneID: timeZoneID,
            familyRepository: familyRepository,
            accessTokenProvider: accessTokenProvider
        )
    }

    func makeMemberEditorViewModel() -> MemberEditorViewModel {
        MemberEditorViewModel(
            familyRepository: familyRepository,
            accessTokenProvider: accessTokenProvider,
            existingMemberIDs: existingMemberIDs
        )
    }
}
