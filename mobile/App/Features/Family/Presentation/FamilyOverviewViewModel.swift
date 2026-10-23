import Foundation
import Observation
import SwiftUI

/// TEL-050 — Família (SPEC-003 Phase 1, UX-003 §5.1). Paginated member list plus the Admin-only entry to TEL-033.
@MainActor
@Observable
final class FamilyOverviewViewModel {
    private(set) var members: [FamilyMember] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var loadFailed = false
    private(set) var loadMoreFailed = false

    private let session: ActiveFamilySession
    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(
        session: ActiveFamilySession,
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?
    ) {
        self.session = session
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
    }

    /// The server stays the authority (RNF07); this only hides controls the API would refuse.
    var canAddMember: Bool { session.role == .administrator }
    var canConfigureFamily: Bool { session.role == .administrator }
    var hasMorePages: Bool { nextCursor != nil }
    var existingMemberIDs: Set<UUID> { Set(members.map(\.id)) }

    var errorMessage: LocalizedStringKey? {
        loadFailed ? "family.overview.error_load" : nil
    }

    /// A failed reload keeps the confirmed members and only reports a non-blocking error.
    func loadInitial() async {
        guard !isLoading else { return }
        loadFailed = false
        guard let token = accessTokenProvider() else {
            loadFailed = true
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await familyRepository.listMembers(accessToken: token, cursor: nil)
            members = page.items
            nextCursor = page.nextCursor
            loadMoreFailed = false
        } catch FamilyError.actionNotAllowed {
            clearConfirmedMembers()
            loadFailed = true
        } catch {
            // Network/availability failures keep the already confirmed list.
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
        guard let token = accessTokenProvider() else {
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

    func memberCreated() async {
        await loadInitial()
    }

    func makeMemberDetailViewModel(memberID: UUID) -> MemberDetailViewModel {
        MemberDetailViewModel(
            memberID: memberID,
            session: session,
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
