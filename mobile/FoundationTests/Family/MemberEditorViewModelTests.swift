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
}
