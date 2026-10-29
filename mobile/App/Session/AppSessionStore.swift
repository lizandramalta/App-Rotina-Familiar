import Foundation
import Observation

/// Supplies an access token; `forceRefresh` renews it even when it still looks valid (unexpected 401).
typealias AccessTokenProvider = @MainActor (_ forceRefresh: Bool) async throws -> String

/// Runs `request` with a token from `provider`. Task and Family repositories map a 401 to `rejected`,
/// so one forced renewal and retry covers a token that expired server-side before its local deadline.
@MainActor
func withAccessToken<T>(
    _ provider: AccessTokenProvider,
    _ request: (String) async throws -> T
) async throws -> T {
    do {
        return try await request(try await provider(false))
    } catch TaskError.rejected, FamilyError.rejected {
        return try await request(try await provider(true))
    }
}

enum AppRootState: Equatable {
    case restoring
    case entry
    case authenticated(ActiveFamilySession)
    case initialProfile(CreationGrant)
}

@MainActor
@Observable
final class AppSessionStore {
    private let repository: any AccessRepository
    private let credentialStore: any SessionCredentialStoring
    private let installationProofProvider: any InstallationProofProviding
    private let refreshCoordinator: SessionRefreshCoordinator

    private(set) var state: AppRootState = .restoring
    private(set) var accessToken: String?
    private(set) var tokenExpiresAt: Date?
    /// In-memory onboarding draft kept while the person re-authenticates after an uncertain creation (CA-09).
    private(set) var onboardingDraft: OnboardingDraft?
    /// Refresh token of a just-created family whose Keychain write failed; persisted again on completion.
    private var pendingRefreshToken: String?

    init(
        repository: any AccessRepository,
        credentialStore: any SessionCredentialStoring,
        installationProofProvider: any InstallationProofProviding,
        refreshCoordinator: SessionRefreshCoordinator = SessionRefreshCoordinator()
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.installationProofProvider = installationProofProvider
        self.refreshCoordinator = refreshCoordinator
    }

    func restore() async {
        guard let refreshToken = try? credentialStore.refreshToken() else {
            state = .entry
            return
        }

        do {
            let installationProof = try installationProofProvider.installationProof()
            let token = try await refreshCoordinator.refresh(
                repository: repository,
                refreshToken: refreshToken,
                installationProof: installationProof
            )
            let profile = try await repository.currentSession(accessToken: token.accessToken)
            store(token)
            state = .authenticated(profile)
        } catch AccessError.sessionExpired, AccessError.sessionRevoked {
            clearCredentials()
            state = .entry
        } catch {
            // Falha de rede ou Keychain não invalida uma sessão ainda recuperável.
            state = .entry
        }
    }

    func apply(_ outcome: AppleSignInOutcome) {
        switch outcome {
        case let .session(session):
            do {
                try credentialStore.save(refreshToken: session.credentials.refreshToken)
                store(session.credentials.token)
                onboardingDraft = nil
                state = .authenticated(session.profile)
            } catch {
                clearCredentials()
                state = .entry
            }
        case let .creationGrant(grant):
            accessToken = nil
            tokenExpiresAt = nil
            state = .initialProfile(grant)
        }
    }

    /// Replaces local credentials only after the invite join was confirmed by the server (SPEC-005 CA-06).
    func applyInviteSession(_ session: AuthenticatedSession) throws {
        // A confirmed remote switch may have revoked the previous session. Hide its protected UI
        // even when the new refresh token cannot yet be written to Keychain.
        state = .restoring
        accessToken = nil
        tokenExpiresAt = nil
        try credentialStore.save(refreshToken: session.credentials.refreshToken)
        onboardingDraft = nil
        pendingRefreshToken = nil
        store(session.credentials.token)
        state = .authenticated(session.profile)
    }

    func accessTokenForConfirmedSwitch() async throws -> String? {
        guard case .authenticated = state else {
            return nil
        }
        guard let refreshToken = try credentialStore.refreshToken() else {
            throw AccessError.sessionExpired
        }
        let installationProof = try installationProofProvider.installationProof()
        let token = try await refreshCoordinator.refresh(
            repository: repository,
            refreshToken: refreshToken,
            installationProof: installationProof
        )
        store(token)
        return token.accessToken
    }

    /// Returns the current access token, renewing it silently when it expires within a minute.
    func validAccessToken() async throws -> String {
        if let accessToken, let tokenExpiresAt, tokenExpiresAt > Date().addingTimeInterval(60) {
            return accessToken
        }
        return try await forceRefreshToken()
    }

    /// Renews the access token even if it still looks valid, e.g. after an unexpected 401.
    /// An expired or revoked session returns to TEL-001; other failures keep the session.
    func forceRefreshToken() async throws -> String {
        guard case .authenticated = state,
              let refreshToken = try credentialStore.refreshToken() ?? pendingRefreshToken else {
            throw AccessError.sessionExpired
        }
        let token: SessionToken
        do {
            token = try await refreshCoordinator.refresh(
                repository: repository,
                refreshToken: refreshToken,
                installationProof: try installationProofProvider.installationProof()
            )
        } catch AccessError.sessionExpired, AccessError.sessionRevoked {
            onboardingDraft = nil
            clearCredentials()
            state = .entry
            throw AccessError.sessionExpired
        }
        // Signed out while the refresh was in flight: never resurrect the session.
        guard case .authenticated = state else { throw AccessError.sessionExpired }
        store(token)
        return token.accessToken
    }

    /// Stores the session returned by `POST /v1/families` without leaving onboarding yet.
    /// Never throws: the family already exists, so a Keychain failure must not abort the flow (CA-10).
    func establishOnboardingSession(_ session: AuthenticatedSession) {
        store(session.credentials.token)
        do {
            try credentialStore.save(refreshToken: session.credentials.refreshToken)
            pendingRefreshToken = nil
        } catch {
            pendingRefreshToken = session.credentials.refreshToken
        }
    }

    func completeOnboarding(profile: ActiveFamilySession) {
        if let pendingRefreshToken {
            // Best effort: without it the next launch falls back to Apple sign-in, which finds the family.
            try? credentialStore.save(refreshToken: pendingRefreshToken)
            self.pendingRefreshToken = nil
        }
        onboardingDraft = nil
        state = .authenticated(profile)
    }

    /// Applies a role transition only after the server confirms it (SPEC-003 CA-05).
    func applyConfirmedRole(_ role: MemberRole) {
        guard case let .authenticated(profile) = state else { return }
        state = .authenticated(ActiveFamilySession(
            memberID: profile.memberID, familyID: profile.familyID,
            role: role, isFamilyCreator: profile.isFamilyCreator
        ))
    }

    /// Returns to TEL-001 keeping the draft, so a new `creationGrant` can resume the form.
    func returnToEntry(preserving draft: OnboardingDraft) {
        onboardingDraft = draft
        state = .entry
    }

    func discardOnboarding() {
        onboardingDraft = nil
        state = .entry
    }

    func signOut() async {
        defer {
            onboardingDraft = nil
            clearCredentials()
            state = .entry
        }

        guard let accessToken else {
            return
        }
        try? await repository.revokeSession(accessToken: accessToken)
    }

    private func store(_ token: SessionToken) {
        accessToken = token.accessToken
        tokenExpiresAt = token.expiresAt
    }

    private func clearCredentials() {
        accessToken = nil
        tokenExpiresAt = nil
        try? credentialStore.clear()
    }
}
