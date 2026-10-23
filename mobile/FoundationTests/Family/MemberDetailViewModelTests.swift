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
        token: String? = "token-1"
    ) -> (MemberDetailViewModel, FamilyRepositorySpy) {
        let repository = FamilyRepositorySpy(memberDetailResult: result)
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
            accessTokenProvider: { token }
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
}
