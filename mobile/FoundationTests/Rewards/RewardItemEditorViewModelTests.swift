import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct RewardItemEditorViewModelTests {
    private func makeViewModel(repository: RewardRepositorySpy = RewardRepositorySpy()) -> RewardItemEditorViewModel {
        RewardItemEditorViewModel(repository: repository, accessToken: "token")
    }

    @Test("UX-015 §5.2: Adicionar item stays disabled until the title isn't empty after trim")
    func formValidityFollowsTrimmedTitle() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isFormValid)

        viewModel.title = "   "
        #expect(!viewModel.isFormValid)

        viewModel.title = "Noite de pizza"
        #expect(viewModel.isFormValid)
    }

    @Test("CA-02: saves with the typed title and details, trimmed title sent to the backend")
    func createSuccess() async {
        let repository = RewardRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "  Noite de pizza  "
        viewModel.details = "Escolher juntos o sabor e o filme"

        await viewModel.saveIfValid()

        #expect(repository.addCalls.count == 1)
        #expect(repository.addCalls.first?.title == "Noite de pizza")
        #expect(repository.addCalls.first?.details == "Escolher juntos o sabor e o filme")
        #expect(viewModel.outcome == .saved(RewardRepositorySpy.fixture))
    }

    @Test("CA-03: an invalid title blocks the save, shows the inline error and preserves the draft")
    func blocksSaveOnInvalidTitle() async {
        let repository = RewardRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "   "
        viewModel.details = "Alguma descrição"

        await viewModel.saveIfValid()

        #expect(repository.addCalls.isEmpty)
        #expect(viewModel.titleError == .required)
        #expect(viewModel.details == "Alguma descrição")
    }

    @Test("CA-03: a too-long details shows the inline error without a banner, and preserves the draft")
    func detailsTooLongShowsFieldErrorOnly() async {
        let repository = RewardRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Noite de pizza"
        viewModel.details = String(repeating: "a", count: 256)

        await viewModel.saveIfValid()

        #expect(repository.addCalls.isEmpty)
        #expect(viewModel.detailsError == .invalid)
        #expect(viewModel.banner == nil)
    }

    @Test("Draft fields are preserved and a banner is shown when the save fails over the network")
    func savePreservesDraftOnNetworkFailure() async {
        let repository = RewardRepositorySpy(addResult: .failure(RewardItemError.network))
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Noite de pizza"
        viewModel.details = "Escolher juntos"

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .networkFailure)
        #expect(viewModel.title == "Noite de pizza")
        #expect(viewModel.details == "Escolher juntos")
    }

    @Test("CA-04: a duplicate title shows both the banner and the inline title error, and preserves the draft")
    func duplicateTitleShowsBannerAndFieldError() async {
        let repository = RewardRepositorySpy(addResult: .failure(RewardItemError.titleAlreadyExists))
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Noite de pizza"

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .duplicateTitle)
        #expect(viewModel.titleError == .duplicate)
        #expect(viewModel.title == "Noite de pizza")
    }

    @Test("CA-07: an uncertain outcome never claims success and never leaves a banner behind")
    func uncertainOutcomeIsReported() async {
        let repository = RewardRepositorySpy(addResult: .failure(RewardItemError.uncertainOutcome))
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Noite de pizza"

        await viewModel.saveIfValid()

        #expect(viewModel.outcome == .uncertain)
        #expect(viewModel.banner == nil)
    }

    @Test("A server-side validation failure maps to field errors only, with no banner")
    func validationFailedMapsFieldErrors() async {
        let repository = RewardRepositorySpy(addResult: .failure(
            RewardItemError.validationFailed(["title": ["REWARD_TITLE_TOO_LONG"]])
        ))
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Noite de pizza"

        await viewModel.saveIfValid()

        #expect(viewModel.titleError == .invalid)
        #expect(viewModel.banner == nil)
    }
}
