import Foundation
import Observation

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
    private var accessToken: String?

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
            accessToken = token.accessToken
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
                accessToken = session.credentials.token.accessToken
                state = .authenticated(session.profile)
            } catch {
                clearCredentials()
                state = .entry
            }
        case let .creationGrant(grant):
            accessToken = nil
            state = .initialProfile(grant)
        }
    }

    func signOut() async {
        defer {
            clearCredentials()
            state = .entry
        }

        guard let accessToken else {
            return
        }
        try? await repository.revokeSession(accessToken: accessToken)
    }

    private func clearCredentials() {
        accessToken = nil
        try? credentialStore.clear()
    }
}
