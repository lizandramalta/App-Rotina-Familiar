import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct EntryViewModelTests {
    @Test("SCRUM-16 CA-03 leaves TEL-001 idle when Apple login is cancelled")
    func cancellationDoesNotCallTheAPI() async {
        let repository = AccessRepositorySpy(signInResult: .failure(.unavailable))
        let sessionStore = makeSessionStore(repository: repository)
        let viewModel = EntryViewModel(
            appleAuthenticator: AppleAuthenticatorStub(result: .failure(.cancelled)),
            signIn: SignInWithAppleUseCase(
                repository: repository,
                installationProofProvider: InstallationProofStub()
            ),
            sessionStore: sessionStore
        )

        await viewModel.signInWithApple()

        #expect(viewModel.state == .idle)
        let callCount = await repository.signInCallCount()
        #expect(callCount == 0)
    }

    @Test("SCRUM-16 exposes invalid Apple proof as non-blocking feedback")
    func invalidAppleProofShowsFeedback() async {
        let repository = AccessRepositorySpy(signInResult: .failure(.appleProofInvalid))
        let sessionStore = makeSessionStore(repository: repository)
        let viewModel = EntryViewModel(
            appleAuthenticator: AppleAuthenticatorStub(result: .success(proof)),
            signIn: SignInWithAppleUseCase(
                repository: repository,
                installationProofProvider: InstallationProofStub()
            ),
            sessionStore: sessionStore
        )

        await viewModel.signInWithApple()

        #expect(viewModel.state == .error(.appleProofInvalid))
    }

    @Test("SCRUM-16 CA-10 returns to a retryable network-feedback state")
    func networkFailureDoesNotOpenASession() async {
        let repository = AccessRepositorySpy(signInResult: .failure(.network))
        let sessionStore = makeSessionStore(repository: repository)
        let viewModel = EntryViewModel(
            appleAuthenticator: AppleAuthenticatorStub(result: .success(proof)),
            signIn: SignInWithAppleUseCase(
                repository: repository,
                installationProofProvider: InstallationProofStub()
            ),
            sessionStore: sessionStore
        )

        await viewModel.signInWithApple()

        #expect(viewModel.state == .error(.network))
        #expect(sessionStore.state == .restoring)
    }

    @Test("SCRUM-16 CA-01 stores only the refresh credential and opens the authenticated root")
    func sessionResultOpensAuthenticatedRoot() async {
        let credentials = CredentialStoreStub()
        let repository = AccessRepositorySpy(signInResult: .success(.session(authenticatedSession)))
        let sessionStore = makeSessionStore(repository: repository, credentials: credentials)
        let viewModel = EntryViewModel(
            appleAuthenticator: AppleAuthenticatorStub(result: .success(proof)),
            signIn: SignInWithAppleUseCase(
                repository: repository,
                installationProofProvider: InstallationProofStub()
            ),
            sessionStore: sessionStore
        )

        await viewModel.signInWithApple()

        #expect(sessionStore.state == .authenticated(authenticatedSession.profile))
        #expect(credentials.savedRefreshToken == authenticatedSession.credentials.refreshToken)
    }

    @Test("SCRUM-16 CA-02 keeps the creation grant in memory and routes to TEL-055")
    func creationGrantStartsInitialProfileFlow() async {
        let grant = CreationGrant(value: "grant", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        let repository = AccessRepositorySpy(signInResult: .success(.creationGrant(grant)))
        let sessionStore = makeSessionStore(repository: repository)
        let viewModel = EntryViewModel(
            appleAuthenticator: AppleAuthenticatorStub(result: .success(proof)),
            signIn: SignInWithAppleUseCase(
                repository: repository,
                installationProofProvider: InstallationProofStub()
            ),
            sessionStore: sessionStore
        )

        await viewModel.signInWithApple()

        #expect(sessionStore.state == .initialProfile(grant))
    }

    private func makeSessionStore(
        repository: any AccessRepository,
        credentials: CredentialStoreStub = CredentialStoreStub()
    ) -> AppSessionStore {
        AppSessionStore(
            repository: repository,
            credentialStore: credentials,
            installationProofProvider: InstallationProofStub()
        )
    }

    private var proof: AppleAuthorizationProof {
        AppleAuthorizationProof(identityToken: "identity", authorizationCode: "code", rawNonce: "nonce")
    }

    private var authenticatedSession: AuthenticatedSession {
        AuthenticatedSession(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            profile: ActiveFamilySession(
                memberID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                familyID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                role: .administrator,
                isFamilyCreator: true
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
                refreshToken: "refresh"
            )
        )
    }
}

@MainActor
private final class AppleAuthenticatorStub: AppleAuthenticating {
    private let result: Result<AppleAuthorizationProof, AppleAuthenticationError>

    init(result: Result<AppleAuthorizationProof, AppleAuthenticationError>) {
        self.result = result
    }

    func authorize() async throws -> AppleAuthorizationProof {
        try result.get()
    }
}

private actor AccessRepositorySpy: AccessRepository {
    private let result: Result<AppleSignInOutcome, AccessError>
    private var signInCalls = 0

    init(signInResult: Result<AppleSignInOutcome, AccessError>) {
        result = signInResult
    }

    func signIn(
        proof: AppleAuthorizationProof,
        installationProof: String
    ) async throws -> AppleSignInOutcome {
        signInCalls += 1
        return try result.get()
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        throw AccessError.unavailable
    }

    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        throw AccessError.unavailable
    }

    func revokeSession(accessToken: String) async throws {}

    func signInCallCount() -> Int {
        signInCalls
    }
}

private final class CredentialStoreStub: SessionCredentialStoring, @unchecked Sendable {
    var savedRefreshToken: String?

    func refreshToken() throws -> String? {
        savedRefreshToken
    }

    func save(refreshToken: String) throws {
        savedRefreshToken = refreshToken
    }

    func clear() throws {
        savedRefreshToken = nil
    }
}

private struct InstallationProofStub: InstallationProofProviding {
    func installationProof() throws -> String {
        "installation-proof"
    }
}
