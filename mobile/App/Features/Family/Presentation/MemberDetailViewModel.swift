import Foundation
import Observation
import SwiftUI

/// TEL-032 — Detalhe do membro (SPEC-003 Phase 1, UX-003 §5.2). Read-only: invite, role change and removal
/// belong to later phases.
@MainActor
@Observable
final class MemberDetailViewModel {
    enum Failure: Equatable {
        case notAllowed
        case notFound
        case network
    }

    private(set) var detail: FamilyMemberDetail?
    private(set) var isLoading = false
    private(set) var failure: Failure?

    private let memberID: UUID
    private let session: ActiveFamilySession
    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(
        memberID: UUID,
        session: ActiveFamilySession,
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?
    ) {
        self.memberID = memberID
        self.session = session
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
    }

    var isCreator: Bool { detail?.isFamilyCreator ?? false }

    var canManage: Bool {
        session.role == .administrator && (detail?.capabilities.manageMembers ?? false)
    }

    var errorMessage: LocalizedStringKey? {
        switch failure {
        case .notAllowed: "family.member.detail.error_not_allowed"
        case .notFound: "family.member.detail.error_not_found"
        case .network: "family.members.error_network"
        case nil: nil
        }
    }

    /// A failed reload keeps the last confirmed detail (UX-003 §6) and only reports the error.
    func load() async {
        guard !isLoading else { return }
        failure = nil
        guard let token = accessTokenProvider() else {
            failure = .network
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await familyRepository.getMemberDetail(memberID: memberID, accessToken: token)
        } catch FamilyError.actionNotAllowed {
            failure = .notAllowed
        } catch FamilyError.rejected {
            // 404: the member no longer exists, so stale data must not stay on screen.
            detail = nil
            failure = .notFound
        } catch {
            failure = .network
        }
    }
}
