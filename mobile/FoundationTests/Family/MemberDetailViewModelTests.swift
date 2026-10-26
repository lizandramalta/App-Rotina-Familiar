import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MemberDetailViewModelTests {
    private let memberID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!

    private func detail(isCreator: Bool = false, manageMembers: Bool) -> FamilyMemberDetail {
        FamilyMemberDetail(
            id: memberID,
            name: "Maria Silva",
            role: .administrator,
            isFamilyCreator: isCreator,
            createdAt: "2026-10-01T12:00:00.000Z",
            capabilities: MemberCapabilities(manageMembers: manageMembers)
        )
    }

    private func makeViewModel(
        _ result: Result<FamilyMemberDetail, Error>,
        viewerRole: MemberRole = .administrator,
        token: String? = "token-1",
        inviteResults: [Result<MemberInvite, Error>] = [],
        hasPreviousInvite: Bool = false
    ) -> (MemberDetailViewModel, FamilyRepositorySpy) {
        let repository = FamilyRepositorySpy(memberDetailResult: result, inviteResults: inviteResults)
        let session = ActiveFamilySession(
            memberID: UUID(),
            familyID: UUID(),
            role: viewerRole,
            isFamilyCreator: false
        )
        let viewModel = MemberDetailViewModel(
            memberID: memberID,
            session: session,
            familyRepository: repository,
            accessTokenProvider: { token },
            hasPreviousInvite: hasPreviousInvite
        )
        return (viewModel, repository)
    }

    @Test("SPEC-003 CA-01 loads the detail and lets an administrator with capability manage")
    func loadsForAdministrator() async {
        let (viewModel, repository) = makeViewModel(.success(detail(manageMembers: true)))

        await viewModel.load()

        #expect(viewModel.detail?.name == "Maria Silva")
        #expect(repository.memberDetailRequests == [memberID])
        #expect(!viewModel.isCreator)
        #expect(viewModel.canManage)
        #expect(viewModel.failure == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("SPEC-003 CA-02 exposes the Creator condition")
    func exposesCreator() async {
        let (viewModel, _) = makeViewModel(.success(detail(isCreator: true, manageMembers: true)))

        await viewModel.load()

        #expect(viewModel.isCreator)
    }

    @Test("SPEC-003 CA-03 a consulting Member cannot manage")
    func memberCannotManage() async {
        let (viewModel, _) = makeViewModel(.success(detail(manageMembers: false)), viewerRole: .member)

        await viewModel.load()

        #expect(viewModel.detail != nil)
        #expect(!viewModel.canManage)
    }

    @Test("SPEC-003 CA-03 the capability is required even for an administrator")
    func capabilityRequired() async {
        let (viewModel, _) = makeViewModel(.success(detail(manageMembers: false)), viewerRole: .administrator)

        await viewModel.load()

        #expect(!viewModel.canManage)
    }

    @Test("SPEC-003 CA-03 maps 403, 404 and network failures")
    func mapsErrors() async {
        let cases: [(FamilyError, MemberDetailViewModel.Failure)] = [
            (.actionNotAllowed, .notAllowed),
            (.rejected, .notFound),
            (.network, .network),
            (.unavailable, .network),
        ]
        for (error, expected) in cases {
            let (viewModel, _) = makeViewModel(.failure(error))

            await viewModel.load()

            #expect(viewModel.failure == expected)
            #expect(viewModel.detail == nil)
            #expect(!viewModel.isLoading)
        }
    }

    @Test("SPEC-003 CA-07 a failed reload keeps the last confirmed detail, except when the member is gone")
    func reloadFailureKeepsConfirmedDetail() async {
        let repository = FamilyRepositorySpy(memberDetailResult: .success(detail(manageMembers: true)))
        let viewModel = MemberDetailViewModel(
            memberID: memberID,
            session: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .administrator, isFamilyCreator: false),
            familyRepository: repository,
            accessTokenProvider: { "token-1" }
        )
        await viewModel.load()
        repository.setMemberDetailResult(.failure(FamilyError.network))

        await viewModel.load()

        #expect(viewModel.detail != nil)
        #expect(viewModel.failure == .network)

        repository.setMemberDetailResult(.failure(FamilyError.rejected))
        await viewModel.load()

        #expect(viewModel.detail == nil)
        #expect(viewModel.failure == .notFound)
    }

    @Test("SPEC-003 CA-07 without an access token nothing is requested")
    func missingToken() async {
        let (viewModel, repository) = makeViewModel(.success(detail(manageMembers: true)), token: nil)

        await viewModel.load()

        #expect(viewModel.failure == .network)
        #expect(repository.memberDetailRequests.isEmpty)
    }

    @Test("SPEC-003 CA-03 a 403 on reload clears the previously loaded detail")
    func reloadForbiddenClearsDetail() async {
        let repository = FamilyRepositorySpy(memberDetailResult: .success(detail(manageMembers: true)))
        let viewModel = MemberDetailViewModel(
            memberID: memberID,
            session: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .administrator, isFamilyCreator: false),
            familyRepository: repository,
            accessTokenProvider: { "token-1" }
        )
        await viewModel.load()
        #expect(viewModel.detail != nil)
        repository.setMemberDetailResult(.failure(FamilyError.actionNotAllowed))

        await viewModel.load()

        #expect(viewModel.detail == nil)
        #expect(viewModel.failure == .notAllowed)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isCreator)
        #expect(!viewModel.canManage)
    }

    // MARK: SPEC-004 Phase 2 — invite issue and reissue

    private func invite(_ password: String = "PW") -> MemberInvite {
        MemberInvite(inviteID: UUID(), link: "https://example.test/i", password: password)
    }

    private func loadedViewModel(
        inviteResults: [Result<MemberInvite, Error>] = [.success(MemberInvite(inviteID: UUID(), link: "https://example.test/i", password: "PW"))],
        hasPreviousInvite: Bool = false
    ) async -> (MemberDetailViewModel, FamilyRepositorySpy) {
        let (viewModel, repository) = makeViewModel(
            .success(detail(manageMembers: true)),
            inviteResults: inviteResults,
            hasPreviousInvite: hasPreviousInvite
        )
        await viewModel.load()
        return (viewModel, repository)
    }

    @Test("SPEC-004 CA-01 the first issuance is direct and exposes the credentials for the share sheet")
    func firstIssuance() async {
        let (viewModel, repository) = await loadedViewModel()
        #expect(viewModel.canIssueInvite)
        #expect(!viewModel.hasPreviousInvite)

        await viewModel.issueFirstInvite()

        #expect(repository.invitedMemberIDs == [memberID])
        #expect(viewModel.transientInvite != nil)
        #expect(viewModel.shareMessage?.contains("https://example.test/i") == true)
        #expect(viewModel.shareMessage?.contains("PW") == true)
        #expect(viewModel.inviteFailure == nil)
        #expect(!viewModel.isIssuingInvite)
    }

    @Test("SPEC-004 CA-08 closing the share sheet discards the credentials and flags the cancellation")
    func shareCancelled() async {
        let (viewModel, repository) = await loadedViewModel()
        await viewModel.issueFirstInvite()

        viewModel.onShareDismissed(completed: false)

        #expect(viewModel.transientInvite == nil)
        #expect(viewModel.shareMessage == nil)
        #expect(viewModel.hasPreviousInvite)
        #expect(viewModel.wasShareCancelled)
        #expect(repository.inviteCalls == 1)
        #expect(viewModel.detail != nil)
    }

    @Test("SPEC-004 CA-08 a completed share discards the credentials without the cancellation notice")
    func shareCompleted() async {
        let (viewModel, _) = await loadedViewModel()
        await viewModel.issueFirstInvite()

        viewModel.onShareDismissed(completed: true)

        #expect(viewModel.transientInvite == nil)
        #expect(viewModel.hasPreviousInvite)
        #expect(!viewModel.wasShareCancelled)
    }

    @Test("SPEC-004 CA-02 a reissue calls the API again and clears the previous cancellation notice")
    func reissue() async {
        let (viewModel, repository) = await loadedViewModel(
            inviteResults: [.success(invite("PW-1")), .success(invite("PW-2"))]
        )
        await viewModel.issueFirstInvite()
        viewModel.onShareDismissed(completed: false)

        await viewModel.confirmReissue()

        #expect(repository.inviteCalls == 2)
        #expect(viewModel.shareMessage?.contains("PW-2") == true)
        #expect(!viewModel.wasShareCancelled)
    }

    @Test("SPEC-004 CA-07 a lost response shows no credentials and turns the next attempt into a reissue")
    func uncertainOutcome() async {
        let errors: [FamilyError] = [.uncertainOutcome, .network, .unavailable]
        for error in errors {
            let (viewModel, _) = await loadedViewModel(inviteResults: [.failure(error)])

            await viewModel.issueFirstInvite()

            #expect(viewModel.inviteFailure == .uncertain)
            #expect(viewModel.transientInvite == nil)
            #expect(viewModel.hasPreviousInvite)
            #expect(viewModel.inviteErrorMessage != nil)
        }
    }

    @Test("SPEC-004 a rejected target is unavailable and 429 stays recoverable")
    func definitiveFailures() async {
        let cases: [(FamilyError, MemberDetailViewModel.InviteFailure)] = [
            (.rejected, .unavailable),
            (.rateLimited, .rateLimited),
            (.actionNotAllowed, .notAllowed),
        ]
        for (error, expected) in cases {
            let (viewModel, _) = await loadedViewModel(inviteResults: [.failure(error)])

            await viewModel.issueFirstInvite()

            #expect(viewModel.inviteFailure == expected)
            #expect(viewModel.transientInvite == nil)
            #expect(!viewModel.hasPreviousInvite)
        }
    }

    @Test("SPEC-004 CA-03/CA-04 the action is not available to Members, Kids' viewers or the Creator target")
    func authorization() async {
        let (member, memberRepository) = makeViewModel(.success(detail(manageMembers: false)), viewerRole: .member)
        await member.load()
        await member.issueFirstInvite()
        #expect(!member.canIssueInvite)
        #expect(memberRepository.inviteCalls == 0)

        let (kid, kidRepository) = makeViewModel(.success(detail(manageMembers: false)), viewerRole: .kid)
        await kid.load()
        await kid.issueFirstInvite()
        #expect(!kid.canIssueInvite)
        #expect(kidRepository.inviteCalls == 0)

        let (creator, creatorRepository) = makeViewModel(.success(detail(isCreator: true, manageMembers: true)))
        await creator.load()
        await creator.issueFirstInvite()
        #expect(!creator.canIssueInvite)
        #expect(creatorRepository.inviteCalls == 0)
    }

    @Test("SPEC-004 losing the access token after loading requests nothing")
    func issuanceWithoutToken() async {
        let repository = FamilyRepositorySpy(memberDetailResult: .success(detail(manageMembers: true)))
        var token: String? = "token-1"
        let viewModel = MemberDetailViewModel(
            memberID: memberID,
            session: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: .administrator, isFamilyCreator: false),
            familyRepository: repository,
            accessTokenProvider: { token }
        )
        await viewModel.load()
        token = nil

        await viewModel.issueFirstInvite()

        #expect(repository.inviteCalls == 0)
        #expect(viewModel.inviteFailure == .notAllowed)
    }

    @Test("SPEC-004 a previous invite can be injected so the reissue path is used")
    func injectedPreviousInvite() async {
        let (viewModel, _) = await loadedViewModel(hasPreviousInvite: true)

        #expect(viewModel.hasPreviousInvite)
    }
}
