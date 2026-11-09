import Foundation
@testable import FamilyRoutine
import Testing

/// TestFlight fix: the access token (15 min TTL) is renewed silently instead of failing with 401.
@MainActor
struct AppSessionStoreTokenTests {
    private final class RefreshingAccessRepository: AccessRepository, @unchecked Sendable {
        var refreshResult: Result<SessionToken, Error>
        private(set) var refreshCalls = 0

        init(refreshResult: Result<SessionToken, Error>) { self.refreshResult = refreshResult }

        func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
            throw AccessError.unavailable
        }
        func currentSession(accessToken: String) async throws -> ActiveFamilySession { throw AccessError.unavailable }
        func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
            refreshCalls += 1
            return try refreshResult.get()
        }
        func revokeSession(accessToken: String) async throws {}
    }

    private func makeStore(
        expiresAt: Date,
        refreshResult: Result<SessionToken, Error> = .success(SessionToken(accessToken: "access-2", expiresAt: .now.addingTimeInterval(900)))
    ) -> (AppSessionStore, RefreshingAccessRepository, FamilyCredentialStoreStub) {
        let repository = RefreshingAccessRepository(refreshResult: refreshResult)
        let credentials = FamilyCredentialStoreStub()
        let store = AppSessionStore(
            repository: repository,
            credentialStore: credentials,
            installationProofProvider: FamilyInstallationProofStub()
        )
        store.apply(.session(AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .administrator, isFamilyCreator: true),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access-1", expiresAt: expiresAt),
                refreshToken: "refresh-1"
            )
        )))
        return (store, repository, credentials)
    }

    @Test("A token valid for more than a minute is reused without a refresh")
    func reusesValidToken() async throws {
        let (store, repository, _) = makeStore(expiresAt: .now.addingTimeInterval(600))

        #expect(try await store.validAccessToken() == "access-1")
        #expect(repository.refreshCalls == 0)
    }

    @Test("A token expiring within a minute is renewed silently")
    func renewsExpiringToken() async throws {
        let (store, repository, _) = makeStore(expiresAt: .now.addingTimeInterval(30))

        #expect(try await store.validAccessToken() == "access-2")
        #expect(store.accessToken == "access-2")
        #expect(repository.refreshCalls == 1)
    }

    @Test("A forced refresh renews a token that still looks valid")
    func forcedRefresh() async throws {
        let (store, repository, _) = makeStore(expiresAt: .now.addingTimeInterval(600))

        #expect(try await store.forceRefreshToken() == "access-2")
        #expect(repository.refreshCalls == 1)
    }

    @Test("An expired session clears credentials and returns to entry")
    func expiredSessionReturnsToEntry() async {
        let (store, _, credentials) = makeStore(expiresAt: .distantPast, refreshResult: .failure(AccessError.sessionExpired))

        await #expect(throws: AccessError.self) { try await store.validAccessToken() }

        #expect(store.state == .entry)
        #expect(store.accessToken == nil)
        #expect(credentials.savedRefreshToken == nil)
    }

    @Test("A network failure keeps the session")
    func networkFailureKeepsSession() async {
        let (store, _, credentials) = makeStore(expiresAt: .distantPast, refreshResult: .failure(AccessError.unavailable))

        await #expect(throws: AccessError.self) { try await store.validAccessToken() }

        #expect(store.state != .entry)
        #expect(credentials.savedRefreshToken == "refresh-1")
    }
}
