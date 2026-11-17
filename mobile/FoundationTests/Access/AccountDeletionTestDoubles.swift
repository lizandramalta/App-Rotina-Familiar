import Foundation
@testable import FamilyRoutine

/// SPEC-022: access repository whose account deletion and session check are scripted per call.
final class AccountDeletionAccessRepository: AccessRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var deletionResults: [Result<Void, Error>]
    private var _deletionProofs: [AppleAuthorizationProof?] = []
    var currentSessionResult: Result<ActiveFamilySession, Error> = .failure(AccessError.sessionRevoked)
    var refreshResult: Result<SessionToken, Error> = .success(SessionToken(accessToken: "access-2", expiresAt: .distantFuture))

    init(deletionResults: [Result<Void, Error>] = [.success(())]) {
        self.deletionResults = deletionResults
    }

    var deletionProofs: [AppleAuthorizationProof?] { lock.withLock { _deletionProofs } }

    func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
        throw AccessError.unavailable
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        try currentSessionResult.get()
    }

    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        try refreshResult.get()
    }

    func revokeSession(accessToken: String) async throws {}

    func deleteOwnAccount(appleProof: AppleAuthorizationProof?, accessToken: String) async throws {
        let result = lock.withLock { () -> Result<Void, Error> in
            _deletionProofs.append(appleProof)
            return deletionResults.isEmpty ? .success(()) : deletionResults.removeFirst()
        }
        try result.get()
    }
}

@MainActor
final class AccountDeletionAppleAuthenticator: AppleAuthenticating {
    var result: Result<AppleAuthorizationProof, Error>
    private(set) var calls = 0

    init(result: Result<AppleAuthorizationProof, Error>) { self.result = result }

    func authorize() async throws -> AppleAuthorizationProof {
        calls += 1
        return try result.get()
    }
}

@MainActor
func makeAccountDeletionStore(
    repository: AccountDeletionAccessRepository,
    role: MemberRole = .member,
    isFamilyCreator: Bool = false
) -> (AppSessionStore, FamilyCredentialStoreStub) {
    let credentials = FamilyCredentialStoreStub()
    let store = AppSessionStore(
        repository: repository,
        credentialStore: credentials,
        installationProofProvider: FamilyInstallationProofStub()
    )
    store.apply(.session(AuthenticatedSession(
        sessionID: UUID(),
        profile: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: role, isFamilyCreator: isFamilyCreator),
        credentials: SessionCredentials(
            token: SessionToken(accessToken: "access-1", expiresAt: .distantFuture),
            refreshToken: "refresh-1"
        )
    )))
    return (store, credentials)
}
