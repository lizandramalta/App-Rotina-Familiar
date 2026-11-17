import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-022 / UX-022 — TEL-058 and MOD-015: confirmation, Apple fallback, lost response and errors.
@MainActor
struct AccountDeletionViewModelTests {
    private let proof = AppleAuthorizationProof(identityToken: "jwt", authorizationCode: "code", rawNonce: "nonce")

    private func make(
        variant: AccountDeletionViewModel.Variant = .member,
        deletionResults: [Result<Void, Error>] = [.success(())],
        apple: Result<AppleAuthorizationProof, Error>? = nil
    ) -> (AccountDeletionViewModel, AppSessionStore, AccountDeletionAccessRepository, AccountDeletionAppleAuthenticator?) {
        let repository = AccountDeletionAccessRepository(deletionResults: deletionResults)
        let isCreator: Bool = if case .creator = variant { true } else { false }
        let (store, _) = makeAccountDeletionStore(repository: repository, isFamilyCreator: isCreator)
        let authenticator = apple.map { AccountDeletionAppleAuthenticator(result: $0) }
        let viewModel = AccountDeletionViewModel(variant: variant, sessionStore: store, appleAuthenticator: authenticator)
        return (viewModel, store, repository, authenticator)
    }

    @Test("CA-01/CA-09 a confirmed deletion returns to TEL-001 with the confirmation")
    func memberDeletionSucceeds() async {
        let (viewModel, store, repository, _) = make()

        viewModel.requestDeletion()
        #expect(viewModel.isShowingConfirmation)
        await viewModel.confirmDeletion()

        #expect(repository.deletionProofs.count == 1)
        #expect(repository.deletionProofs.first == .some(nil))
        #expect(store.state == .entry)
        #expect(store.entryNotice == .accountDeleted)
        #expect(store.accessToken == nil)
    }

    @Test("UX-01 the creator must type the family name exactly before confirming")
    func creatorMustTypeFamilyName() {
        let (viewModel, _, _, _) = make(variant: .creator(familyName: "Família Silva"))

        #expect(!viewModel.canRequestDeletion)
        viewModel.typedFamilyName = "família silva"
        #expect(!viewModel.canRequestDeletion)
        viewModel.typedFamilyName = "  Família Silva "
        #expect(viewModel.canRequestDeletion)
    }

    @Test("CA-10 a creator without a stored token re-authenticates with Apple and resends once")
    func creatorAppleFallback() async {
        let (viewModel, store, repository, authenticator) = make(
            variant: .creator(familyName: "Casa"),
            deletionResults: [.failure(AccessError.appleProofRequired), .success(())],
            apple: .success(proof)
        )

        await viewModel.confirmDeletion()

        #expect(authenticator?.calls == 1)
        #expect(repository.deletionProofs == [nil, proof])
        #expect(store.entryNotice == .accountDeleted)
    }

    @Test("Cancelling the Apple sheet returns to the screen without an error")
    func appleCancelReturnsToContent() async {
        let (viewModel, store, repository, _) = make(
            variant: .creator(familyName: "Casa"),
            deletionResults: [.failure(AccessError.appleProofRequired)],
            apple: .failure(AppleAuthenticationError.cancelled)
        )

        await viewModel.confirmDeletion()

        #expect(viewModel.state == .content)
        #expect(repository.deletionProofs.count == 1)
        if case .authenticated = store.state {} else { Issue.record("session must stay active") }
    }

    @Test("CA-11 a refused Apple proof shows the Apple error and keeps the session")
    func appleProofInvalid() async {
        let (viewModel, store, _, _) = make(
            variant: .creator(familyName: "Casa"),
            deletionResults: [.failure(AccessError.appleProofRequired), .failure(AccessError.appleProofInvalid)],
            apple: .success(proof)
        )

        await viewModel.confirmDeletion()

        #expect(viewModel.state == .failed(.apple))
        if case .authenticated = store.state {} else { Issue.record("session must stay active") }
    }

    @Test("CA-08 a lost response is reconciled: a refused session means the deletion went through")
    func lostResponseDeleted() async {
        let (viewModel, store, repository, _) = make(deletionResults: [.failure(AccessError.network)])
        repository.currentSessionResult = .failure(AccessError.sessionRevoked)

        await viewModel.confirmDeletion()

        #expect(repository.deletionProofs.count == 1)
        #expect(store.entryNotice == .accountDeleted)
        #expect(store.state == .entry)
    }

    @Test("CA-08 a lost response with the session still active offers a retry without resending")
    func lostResponseStillActive() async {
        let (viewModel, store, repository, _) = make(deletionResults: [.failure(AccessError.unavailable)])
        repository.currentSessionResult = .success(
            ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .member, isFamilyCreator: false)
        )

        await viewModel.confirmDeletion()

        #expect(viewModel.state == .failed(.generic))
        #expect(repository.deletionProofs.count == 1)
        if case .authenticated = store.state {} else { Issue.record("session must stay active") }
    }

    @Test("CA-08 an unverifiable outcome reports the network failure")
    func lostResponseUnknown() async {
        let (viewModel, _, repository, _) = make(deletionResults: [.failure(AccessError.network)])
        repository.currentSessionResult = .failure(AccessError.network)

        await viewModel.confirmDeletion()

        #expect(viewModel.state == .failed(.network))
    }

    @Test("CA-20 a session revoked meanwhile ends with the neutral notice")
    func revokedMeanwhile() async {
        let (viewModel, store, _, _) = make(deletionResults: [.failure(AccessError.sessionRevoked)])

        await viewModel.confirmDeletion()

        #expect(store.state == .entry)
        #expect(store.entryNotice == .accessEnded)
    }
}
