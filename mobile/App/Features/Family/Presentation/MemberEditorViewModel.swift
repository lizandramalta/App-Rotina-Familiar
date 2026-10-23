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

    private struct PendingAttempt: Equatable {
        let name: String
        let role: MemberRole
    }

    /// The POST whose outcome is unknown (CA-07). The next save resolves it against the confirmed list first,
    /// using these values even if the draft was edited since.
    private var pendingAttempt: PendingAttempt?
    /// IDs confirmed before the first POST, so a pre-existing profile with the same name and role is never
    /// mistaken for the one an uncertain POST may have created (CA-07).
    private var baselineMemberIDs: Set<UUID>?

    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?,
        existingMemberIDs: Set<UUID>? = nil
    ) {
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
        self.baselineMemberIDs = existingMemberIDs
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if baselineMemberIDs == nil {
                // Nothing has been sent yet, so failing here is safe and keeps the draft.
                baselineMemberIDs = Set(try await confirmedMembers(accessToken: token).map(\.id))
            }
            if let pending = pendingAttempt {
                let created = try await createdMember(for: pending, accessToken: token)
                pendingAttempt = nil
                if let created {
                    baselineMemberIDs?.insert(created.id)
                    if pending == PendingAttempt(name: trimmedName, role: role) {
                        return true
                    }
                }
            }
        } catch FamilyError.actionNotAllowed {
            failure = .notAllowed
            return false
        } catch {
            failure = .network
            return false
        }
        return await create(name: trimmedName, accessToken: token)
    }

    private func create(name trimmedName: String, accessToken token: String) async -> Bool {
        do {
            _ = try await familyRepository.createMember(
                name: trimmedName,
                role: role,
                accessToken: token
            )
            return true
        } catch FamilyError.validationFailed {
            nameError = .invalidContent
        } catch FamilyError.actionNotAllowed {
            failure = .notAllowed
        } catch FamilyError.network, FamilyError.unavailable, FamilyError.uncertainOutcome {
            pendingAttempt = PendingAttempt(name: trimmedName, role: role)
            failure = .network
        } catch {
            // rateLimited, rejected: definitively not created, so a plain retry is safe.
            failure = .network
        }
        return false
    }

    /// A profile counts as created by the uncertain POST only if it matches the attempt and was not in the baseline.
    private func createdMember(for attempt: PendingAttempt, accessToken: String) async throws -> FamilyMember? {
        let baseline = baselineMemberIDs ?? []
        return try await confirmedMembers(accessToken: accessToken).first {
            $0.name == attempt.name && $0.role == attempt.role && !baseline.contains($0.id)
        }
    }

    /// Walks every page of confirmed members (families are small).
    private func confirmedMembers(accessToken: String) async throws -> [FamilyMember] {
        var members: [FamilyMember] = []
        var cursor: String?
        repeat {
            let page = try await familyRepository.listMembers(accessToken: accessToken, cursor: cursor)
            members += page.items
            cursor = page.nextCursor
        } while cursor != nil
        return members
    }
}
