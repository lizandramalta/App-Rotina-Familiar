import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MemberEditorViewModelTests {
    private func makeViewModel(
        _ repository: FamilyRepositorySpy,
        token: String? = "token-1"
    ) -> MemberEditorViewModel {
        MemberEditorViewModel(familyRepository: repository, accessTokenProvider: { token })
    }

    @Test("SPEC-003 CA-01 creates the member with the trimmed name and chosen role")
    func createsMember() async {
        let repository = FamilyRepositorySpy()
        let viewModel = makeViewModel(repository)
        viewModel.name = "  Rafa Silva  "
        viewModel.role = .kid

        let saved = await viewModel.save()

        #expect(saved)
        #expect(repository.createdMembers.map(\.name) == ["Rafa Silva"])
        #expect(repository.createdMembers.map(\.role) == [.kid])
        #expect(viewModel.nameError == nil)
        #expect(viewModel.generalError == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("SPEC-003 CA-02 rejects empty and over-limit names locally without calling the API")
    func localValidation() async {
        let repository = FamilyRepositorySpy()
        let viewModel = makeViewModel(repository)

        viewModel.name = "   "
        #expect(await viewModel.save() == false)
        #expect(viewModel.nameError == .required)

        viewModel.name = String(repeating: "a", count: 61)
        #expect(await viewModel.save() == false)
        #expect(viewModel.nameError == .invalidLength)

        #expect(repository.createdMembers.isEmpty)
    }

    @Test("SPEC-003 CA-02 maps a 422 to a name error and keeps the draft")
    func serverValidationKeepsDraft() async {
        let repository = FamilyRepositorySpy(memberResults: [.failure(FamilyError.validationFailed(["name": ["INVALID"]]))])
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"
        viewModel.role = .administrator

        #expect(await viewModel.save() == false)

        #expect(viewModel.nameError != nil)
        #expect(viewModel.name == "Rafa")
        #expect(viewModel.role == .administrator)
        #expect(!viewModel.isLoading)
    }

    @Test("SPEC-003 CA-03 maps a 403 to a permission error and keeps the draft")
    func actionNotAllowedKeepsDraft() async {
        let repository = FamilyRepositorySpy(memberResults: [.failure(FamilyError.actionNotAllowed)])
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"
        viewModel.role = .kid

        #expect(await viewModel.save() == false)

        #expect(viewModel.failure == .notAllowed)
        #expect(viewModel.name == "Rafa")
        #expect(viewModel.role == .kid)
    }

    @Test("SPEC-003 CA-07 keeps the draft and shows a recoverable error on network or uncertain outcome")
    func networkFailureKeepsDraft() async {
        for error in [FamilyError.network, .uncertainOutcome, .unavailable] {
            let repository = FamilyRepositorySpy(memberResults: [.failure(error)])
            let viewModel = makeViewModel(repository)
            viewModel.name = "Rafa"
            viewModel.role = .kid

            #expect(await viewModel.save() == false)

            #expect(viewModel.failure == .network)
            #expect(viewModel.name == "Rafa")
            #expect(viewModel.role == .kid)
            #expect(viewModel.nameError == nil)
            #expect(!viewModel.isLoading)
        }
    }

    @Test("SPEC-003 CA-07 a retry after a failure can succeed and clears the error")
    func retryAfterFailure() async {
        let repository = FamilyRepositorySpy(memberResults: [.failure(FamilyError.network)])
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"

        #expect(await viewModel.save() == false)
        #expect(await viewModel.save())
        #expect(viewModel.failure == nil)
    }

    @Test("SPEC-003 CA-01 without an access token nothing is sent and the draft stays")
    func missingToken() async {
        let repository = FamilyRepositorySpy()
        let viewModel = makeViewModel(repository, token: nil)
        viewModel.name = "Rafa"

        #expect(await viewModel.save() == false)
        #expect(viewModel.failure == .network)
        #expect(repository.createdMembers.isEmpty)
    }

    @Test("TEL-033 tracks unsaved changes and submit availability")
    func unsavedChanges() {
        let viewModel = makeViewModel(FamilyRepositorySpy())
        #expect(!viewModel.hasUnsavedChanges)
        #expect(!viewModel.canSubmit)

        viewModel.name = "R"
        #expect(viewModel.hasUnsavedChanges)
        #expect(viewModel.canSubmit)

        viewModel.name = ""
        viewModel.role = .kid
        #expect(viewModel.hasUnsavedChanges)
        #expect(!viewModel.canSubmit)
    }

    private func page(_ members: FamilyMember..., next: String? = nil) -> Result<FamilyMemberPage, Error> {
        .success(FamilyMemberPage(items: members, nextCursor: next))
    }

    @Test("SPEC-003 CA-07 confirms a NEW profile found after an uncertain POST without posting again")
    func reconcilesWithoutDuplicate() async {
        let created = FamilyMember(id: UUID(), name: "Rafa", role: .kid, isFamilyCreator: false)
        for error in [FamilyError.network, .uncertainOutcome, .unavailable] {
            let repository = FamilyRepositorySpy(
                memberResults: [.failure(error)],
                listMembersResults: [page(), page(created)]
            )
            let viewModel = makeViewModel(repository)
            viewModel.name = "Rafa"
            viewModel.role = .kid

            #expect(await viewModel.save() == false)
            #expect(await viewModel.save())

            #expect(repository.createMemberCalls == 1)
            #expect(repository.listMembersCalls == 2)
            #expect(viewModel.failure == nil)
        }
    }

    @Test("SPEC-003 CA-07 does not mistake a pre-existing profile with the same name and role for the new one")
    func preExistingProfileIsNotAFalsePositive() async {
        let preExisting = FamilyMember(id: UUID(), name: "Rafa", role: .member, isFamilyCreator: false)
        let repository = FamilyRepositorySpy(
            memberResults: [.failure(FamilyError.network)],
            listMembersResults: [page(preExisting), page(preExisting)]
        )
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"
        viewModel.role = .member

        #expect(await viewModel.save() == false)
        #expect(await viewModel.save())

        #expect(repository.createMemberCalls == 2)
    }

    @Test("SPEC-003 CA-07 an injected baseline replaces the initial lookup")
    func injectedBaseline() async {
        let preExisting = FamilyMember(id: UUID(), name: "Rafa", role: .member, isFamilyCreator: false)
        let repository = FamilyRepositorySpy(
            memberResults: [.failure(FamilyError.network)],
            listMembersResults: [page(preExisting)]
        )
        let viewModel = MemberEditorViewModel(
            familyRepository: repository,
            accessTokenProvider: { "token-1" },
            existingMemberIDs: [preExisting.id]
        )
        viewModel.name = "Rafa"

        #expect(await viewModel.save() == false)
        #expect(repository.listMembersCalls == 0)
        #expect(await viewModel.save())
        #expect(repository.listMembersCalls == 1)
        #expect(repository.createMemberCalls == 2)
    }

    @Test("SPEC-003 CA-07 retries the POST only after the confirmed list shows no match, across pages")
    func reconcilesThenRetries() async {
        let other = FamilyMember(id: UUID(), name: "Rafa", role: .member, isFamilyCreator: false)
        let repository = FamilyRepositorySpy(
            memberResults: [.failure(FamilyError.network)],
            listMembersResults: [page(), page(other, next: "next"), page()]
        )
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"
        viewModel.role = .kid

        #expect(await viewModel.save() == false)
        #expect(await viewModel.save())

        #expect(repository.listMembersCalls == 3)
        #expect(repository.createMemberCalls == 2)
    }

    @Test("SPEC-003 CA-07 without a baseline nothing is posted and the draft stays")
    func baselineLookupFails() async {
        let repository = FamilyRepositorySpy(listMembersResults: [.failure(FamilyError.network)])
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"

        #expect(await viewModel.save() == false)
        #expect(repository.createMemberCalls == 0)
        #expect(viewModel.failure == .network)
        #expect(viewModel.name == "Rafa")
        #expect(await viewModel.save())
        #expect(repository.createMemberCalls == 1)
    }

    @Test("SPEC-003 CA-07 keeps the draft and does not POST when the reconciliation lookup fails")
    func reconciliationLookupFails() async {
        let repository = FamilyRepositorySpy(
            memberResults: [.failure(FamilyError.network)],
            listMembersResults: [page(), .failure(FamilyError.network), page()]
        )
        let viewModel = makeViewModel(repository)
        viewModel.name = "Rafa"

        #expect(await viewModel.save() == false)
        #expect(await viewModel.save() == false)
        #expect(repository.createMemberCalls == 1)
        #expect(viewModel.failure == .network)
        #expect(viewModel.name == "Rafa")

        #expect(await viewModel.save())
        #expect(repository.createMemberCalls == 2)
    }
}
