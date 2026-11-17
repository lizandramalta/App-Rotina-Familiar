import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-022 CA-08/CA-09/CA-20 and UX-022 UX-03 — session store side of the account deletion.
@MainActor
struct AppSessionStoreAccountDeletionTests {
    @Test("CA-09 a confirmed deletion clears credentials and opens TEL-001 with the confirmation")
    func deletionClearsSession() async throws {
        let repository = AccountDeletionAccessRepository()
        let (store, credentials) = makeAccountDeletionStore(repository: repository)

        try await store.deleteOwnAccount(appleProof: nil)

        #expect(store.state == .entry)
        #expect(store.entryNotice == .accountDeleted)
        #expect(credentials.savedRefreshToken == nil)
        #expect(store.accessToken == nil)
    }

    @Test("A failed deletion keeps the session and rethrows")
    func failedDeletionKeepsSession() async {
        let repository = AccountDeletionAccessRepository(deletionResults: [.failure(AccessError.appleProofRequired)])
        let (store, _) = makeAccountDeletionStore(repository: repository, role: .administrator, isFamilyCreator: true)

        await #expect(throws: AccessError.appleProofRequired) { try await store.deleteOwnAccount(appleProof: nil) }

        #expect(store.entryNotice == nil)
        if case .authenticated = store.state {} else { Issue.record("session must stay active") }
    }

    @Test("UX-03 a previously active session refused on renewal shows the neutral notice")
    func refusedRenewalShowsAccessEnded() async {
        let repository = AccountDeletionAccessRepository()
        repository.refreshResult = .failure(AccessError.sessionRevoked)
        let (store, _) = makeAccountDeletionStore(repository: repository)

        await #expect(throws: AccessError.self) { try await store.forceRefreshToken() }

        #expect(store.state == .entry)
        #expect(store.entryNotice == .accessEnded)
    }

    @Test("A new session clears the notice")
    func newSessionClearsNotice() {
        let (store, _) = makeAccountDeletionStore(repository: AccountDeletionAccessRepository())
        store.completeAccountDeletion()
        #expect(store.entryNotice == .accountDeleted)

        store.apply(.session(AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .member, isFamilyCreator: false),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access-9", expiresAt: .distantFuture),
                refreshToken: "refresh-9"
            )
        )))

        #expect(store.entryNotice == nil)
    }

    @Test("CA-08 the session check distinguishes deleted, active and unknown")
    func sessionStillActive() async {
        let repository = AccountDeletionAccessRepository()
        let (store, _) = makeAccountDeletionStore(repository: repository)

        repository.currentSessionResult = .failure(AccessError.sessionRevoked)
        #expect(await store.isSessionStillActive() == false)
        repository.currentSessionResult = .failure(AccessError.network)
        #expect(await store.isSessionStillActive() == nil)
        repository.currentSessionResult = .success(
            ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .member, isFamilyCreator: false)
        )
        #expect(await store.isSessionStillActive() == true)
    }

    @Test("Dismissing the notice removes it")
    func dismissNotice() {
        let (store, _) = makeAccountDeletionStore(repository: AccountDeletionAccessRepository())
        store.completeAccountDeletion()

        store.dismissEntryNotice()

        #expect(store.entryNotice == nil)
    }
}
