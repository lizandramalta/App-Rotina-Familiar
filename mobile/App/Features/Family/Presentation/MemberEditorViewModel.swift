import Foundation
import Observation
import SwiftUI

/// TEL-033 — Criar membro (SPEC-003 Phase 1, UX-003 §5.3). Persists through `POST /v1/family/members`;
/// never issues an invite (SPEC-004).
@MainActor
@Observable
final class MemberEditorViewModel {
    enum Failure: Equatable {
        case notAllowed
        case network
    }

    var name = "" {
        didSet { nameError = nil }
    }

    var role: MemberRole = .member

    private(set) var isLoading = false
    private(set) var nameError: FamilyCreationValidation.TextError?
    private(set) var failure: Failure?

    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(familyRepository: any FamilyRepository, accessTokenProvider: @escaping @MainActor () -> String?) {
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
    }

    var hasUnsavedChanges: Bool {
        !name.isEmpty || role != .member
    }

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var generalError: LocalizedStringKey? {
        switch failure {
        case .notAllowed: "family.members.error_not_allowed"
        case .network: "family.members.error_network"
        case nil: nil
        }
    }

    @discardableResult
    func validateName() -> Bool {
        switch FamilyCreationValidation.validatedName(name) {
        case .success:
            nameError = nil
            return true
        case let .failure(error):
            nameError = error
            return false
        }
    }

    /// Returns `true` only when the server confirmed the creation. Every failure keeps the typed draft (CA-07).
    func save() async -> Bool {
        guard !isLoading, validateName() else { return false }
        failure = nil
        guard let token = accessTokenProvider() else {
            failure = .network
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await familyRepository.createMember(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                role: role,
                accessToken: token
            )
            return true
        } catch FamilyError.validationFailed {
            nameError = .invalidContent
        } catch FamilyError.actionNotAllowed {
            failure = .notAllowed
        } catch {
            // uncertainOutcome, network, unavailable, rateLimited, rejected: nothing is confirmed saved.
            failure = .network
        }
        return false
    }
}
