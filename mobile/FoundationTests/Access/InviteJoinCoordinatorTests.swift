import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct InviteJoinCoordinatorTests {
    private let link = URL(string: "https://links.example.test/invite/opaque_token-1")!

    @Test("SPEC-005 CA-06: cancelling MOD-013 keeps the previous session and does not inspect or join")
    func cancellingSwitchPreservesContext() async {
        let harness = makeHarness(oldSession: true)

        await harness.flow.open(link)
        #expect(harness.flow.showsSwitchConfirmation)
        harness.flow.cancelSwitch()

        #expect(harness.session.state == .authenticated(oldSession.profile))
        #expect(await harness.repository.inspectCount == 0)
        #expect(await harness.repository.joinCount == 0)
    }

    @Test("SPEC-005 CA-06: invalid password keeps previous access and sends confirmed switch with its bearer")
    func invalidPasswordPreservesContext() async {
        let harness = makeHarness(oldSession: true, join: .failure(.invalidPassword))

        await harness.flow.open(link)
        await harness.flow.confirmSwitch()
        harness.flow.password = "WRONG1"
        await harness.flow.submit()

        #expect(harness.flow.screen == .invalidPassword)
        #expect(harness.flow.password == "WRONG1")
        #expect(harness.session.state == .authenticated(oldSession.profile))
        #expect(await harness.repository.previousAccessToken == "refreshed-old")
        #expect(await harness.repository.switchConfirmed)
        #expect(harness.attempts.value == nil)
    }

    @Test("SPEC-005 CA-06/CA-09: successful join installs Kids session and clears attempt proof")
    func successfulJoinRoutesKids() async {
        let harness = makeHarness(oldSession: true, join: .success(kidsSession))

        await harness.flow.open(link)
        await harness.flow.confirmSwitch()
        harness.flow.password = "ABC234"
        await harness.flow.submit()

        #expect(harness.session.state == .authenticated(kidsSession.profile))
        #expect(harness.credentials.token == "kids-refresh")
        #expect(!harness.flow.isPresented)
        #expect(harness.attempts.value == nil)
        #expect(await harness.repository.joinCount == 1)
        #expect(await harness.repository.recoverCount == 0)
    }

    @Test("SPEC-005 CA-08: uncertain join recovers the same attempt without a second join")
    func uncertainJoinUsesRecovery() async {
        let harness = makeHarness(
            oldSession: false,
            join: .failure(.resultUncertain),
            recover: .success(kidsSession)
        )

        await harness.flow.open(link)
        harness.flow.password = "ABC234"
        await harness.flow.submit()

        #expect(harness.session.state == .authenticated(kidsSession.profile))
        #expect(await harness.repository.joinCount == 1)
        #expect(await harness.repository.recoverCount == 1)
        let joinAttemptID = await harness.repository.joinAttemptID
        let recoverAttemptID = await harness.repository.recoverAttemptID
        #expect(joinAttemptID == recoverAttemptID)
        #expect(harness.attempts.value == nil)
    }

    @Test("SPEC-005 CA-08: unavailable recovery keeps a still-valid previous local session")
    func unavailableRecoveryPreservesOldContext() async {
        let harness = makeHarness(oldSession: true, join: .failure(.resultUncertain))

        await harness.flow.open(link)
        await harness.flow.confirmSwitch()
        harness.flow.password = "ABC234"
        await harness.flow.submit()

        #expect(harness.flow.screen == .recoveryUnavailable)
        #expect(harness.session.state == .authenticated(oldSession.profile))
        #expect(harness.attempts.value == nil)
    }

    @Test("SPEC-005 CA-06: a Keychain write failure hides the revoked context and keeps recovery proof")
    func failedCredentialWriteKeepsRecovery() async {
        let harness = makeHarness(oldSession: true, join: .success(kidsSession))
        harness.credentials.failSaving = true

        await harness.flow.open(link)
        await harness.flow.confirmSwitch()
        harness.flow.password = "ABC234"
        await harness.flow.submit()

        #expect(harness.session.state == .restoring)
        #expect(harness.flow.screen == .recoveryRetryable)
        #expect(harness.attempts.value != nil)
    }

    private func makeHarness(
        oldSession: Bool,
        join: Result<AuthenticatedSession, InviteJoinError>? = nil,
        recover: Result<AuthenticatedSession, InviteJoinError> = .failure(.recoveryUnavailable)
    ) -> Harness {
        let credentials = InviteCredentialStoreStub()
        let session = AppSessionStore(
            repository: InviteAccessRepositoryStub(),
            credentialStore: credentials,
            installationProofProvider: InviteInstallationProofStub()
        )
        if oldSession {
            session.apply(.session(self.oldSession))
        } else {
            session.discardOnboarding()
        }
        let repository = InviteJoinRepositoryStub(joinResult: join ?? .success(kidsSession), recoverResult: recover)
        let attempts = InviteAttemptStoreStub()
        let flow = InviteJoinCoordinator(
            repository: repository,
            attempts: attempts,
            installationProofProvider: InviteInstallationProofStub(),
            parser: InviteLinkParser(baseURL: URL(string: "https://links.example.test")!),
            sessionStore: session
        )
        return Harness(flow: flow, session: session, repository: repository, attempts: attempts, credentials: credentials)
    }

    private var oldSession: AuthenticatedSession {
        makeSession(role: .administrator, refresh: "old-refresh")
    }

    private var kidsSession: AuthenticatedSession {
        makeSession(role: .kid, refresh: "kids-refresh")
    }

    private func makeSession(role: MemberRole, refresh: String) -> AuthenticatedSession {
        AuthenticatedSession(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            profile: ActiveFamilySession(
                memberID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                familyID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                role: role,
                isFamilyCreator: role == .administrator
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access-\(refresh)", expiresAt: .distantFuture),
                refreshToken: refresh
            )
        )
    }
}

@MainActor
private struct Harness {
    let flow: InviteJoinCoordinator
    let session: AppSessionStore
    let repository: InviteJoinRepositoryStub
    let attempts: InviteAttemptStoreStub
    let credentials: InviteCredentialStoreStub
}

private actor InviteJoinRepositoryStub: InviteJoinRepository {
    let joinResult: Result<AuthenticatedSession, InviteJoinError>
    let recoverResult: Result<AuthenticatedSession, InviteJoinError>
    var inspectCount = 0
    var joinCount = 0
    var recoverCount = 0
    var previousAccessToken: String?
    var switchConfirmed = false
    var joinAttemptID: UUID?
    var recoverAttemptID: UUID?

    init(joinResult: Result<AuthenticatedSession, InviteJoinError>, recoverResult: Result<AuthenticatedSession, InviteJoinError>) {
        self.joinResult = joinResult
        self.recoverResult = recoverResult
    }

    func inspect(token: String) async throws { inspectCount += 1 }

    func join(
        token: String,
        password: String,
        attempt: InviteJoinAttempt,
        switchConfirmed: Bool,
        previousAccessToken: String?
    ) async throws -> AuthenticatedSession {
        joinCount += 1
        joinAttemptID = attempt.id
        self.switchConfirmed = switchConfirmed
        self.previousAccessToken = previousAccessToken
        return try joinResult.get()
    }

    func recover(attempt: InviteJoinAttempt) async throws -> AuthenticatedSession {
        recoverCount += 1
        recoverAttemptID = attempt.id
        return try recoverResult.get()
    }
}

private struct InviteAccessRepositoryStub: AccessRepository {
    func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
        throw AccessError.unavailable
    }
    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        throw AccessError.unavailable
    }
    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        SessionToken(accessToken: "refreshed-old", expiresAt: .distantFuture)
    }
    func revokeSession(accessToken: String) async throws {}
}

private struct InviteInstallationProofStub: InstallationProofProviding {
    func installationProof() throws -> String { "installation-proof" }
}

private final class InviteAttemptStoreStub: InviteJoinAttemptStoring, @unchecked Sendable {
    var value: InviteJoinAttempt?
    func pendingAttempt() throws -> InviteJoinAttempt? { value }
    func save(_ attempt: InviteJoinAttempt) throws { value = attempt }
    func clear() throws { value = nil }
}

private final class InviteCredentialStoreStub: SessionCredentialStoring, @unchecked Sendable {
    var token: String?
    var failSaving = false
    func refreshToken() throws -> String? { token }
    func save(refreshToken: String) throws {
        if failSaving { throw AccessError.unavailable }
        token = refreshToken
    }
    func clear() throws { token = nil }
}
