import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-022 CA-16/CA-17 and UX-022 UX-04 — "Excluir conta e dados" in TEL-032.
@MainActor
struct MemberDetailKidsAccountDeletionTests {
    private let memberID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!

    private func make(
        targetRole: MemberRole,
        viewerRole: MemberRole = .administrator,
        manageMembers: Bool = true
    ) -> (MemberDetailViewModel, FamilyRepositorySpy) {
        let detail = FamilyMemberDetail(
            id: memberID,
            name: "Lia",
            role: targetRole,
            isFamilyCreator: false,
            createdAt: "2026-10-01T12:00:00.000Z",
            capabilities: MemberCapabilities(manageMembers: manageMembers)
        )
        let repository = FamilyRepositorySpy(memberDetailResult: .success(detail))
        let viewModel = MemberDetailViewModel(
            memberID: memberID,
            session: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: viewerRole, isFamilyCreator: false),
            familyRepository: repository,
            accessTokenProvider: { "token-1" }
        )
        return (viewModel, repository)
    }

    @Test("UX-04 the action appears only for an administrator viewing a Kids profile")
    func visibility() async {
        let (kids, _) = make(targetRole: .kid)
        await kids.load()
        #expect(kids.canDeleteKidsAccount)

        let (adult, _) = make(targetRole: .member)
        await adult.load()
        #expect(!adult.canDeleteKidsAccount)

        let (byMember, _) = make(targetRole: .kid, viewerRole: .member, manageMembers: false)
        await byMember.load()
        #expect(!byMember.canDeleteKidsAccount)
    }

    @Test("CA-16 a confirmed deletion closes the detail")
    func deletionSucceeds() async {
        let (viewModel, repository) = make(targetRole: .kid)
        await viewModel.load()

        await viewModel.deleteKidsAccount()

        #expect(repository.deletedKidsAccountIDs == [memberID])
        #expect(viewModel.isRemoved)
        #expect(!viewModel.managementFailed)
    }

    @Test("A refused deletion keeps the detail and reports the failure")
    func deletionFails() async {
        let (viewModel, repository) = make(targetRole: .kid)
        repository.kidsAccountDeletionResult = .failure(FamilyError.actionNotAllowed)
        await viewModel.load()

        await viewModel.deleteKidsAccount()

        #expect(!viewModel.isRemoved)
        #expect(viewModel.managementFailed)
    }

    @Test("Nothing is sent for an adult target")
    func adultTargetIgnored() async {
        let (viewModel, repository) = make(targetRole: .member)
        await viewModel.load()

        await viewModel.deleteKidsAccount()

        #expect(repository.deletedKidsAccountIDs.isEmpty)
    }
}
