import Foundation
@testable import FamilyRoutine
import Testing

/// TEL-052 (SPEC-020 CA-07/CA-08, UX-020 §3) — SCRUM-103.
@MainActor
struct WeeklyRecognitionViewModelTests {
    private func makeViewModel(
        repository: RecognitionRepositorySpy,
        sharing: HighlightSharingSpy = HighlightSharingSpy(),
        session: RecognitionSessionStub = RecognitionSessionStub(),
        audience: RecognitionAudience = .adult
    ) -> WeeklyRecognitionViewModel {
        WeeklyRecognitionViewModel(
            recognitionID: RecognitionFixtures.id,
            audience: audience,
            getRecognition: GetOwnWeeklyRecognitionUseCase(repository: repository, session: session),
            sharing: sharing
        )
    }

    @Test("UX-020 Carregando: starts with a skeleton and no provisional result")
    func startsLoading() {
        let viewModel = makeViewModel(repository: RecognitionRepositorySpy())

        #expect(viewModel.state == .loading)
        #expect(viewModel.recognition == nil)
        #expect(viewModel.headline.isEmpty)
    }

    @Test("CA-07 shows period, points, tasks and the first-place headline")
    func showsResult() async {
        let viewModel = makeViewModel(repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]))

        await viewModel.load()

        #expect(viewModel.state == .loaded(RecognitionFixtures.recognition()))
        #expect(viewModel.headline == String(localized: "recognition.first"))
        #expect(viewModel.periodText == String(format: String(localized: "recognition.period"), "28 set.", "4 out."))
        #expect(viewModel.summaryAccessibilityLabel.contains("42"))
        #expect(viewModel.summaryAccessibilityLabel.contains("12"))
    }

    @Test("CA-07 tie variant uses “Fiquei entre os primeiros…” in headline and suggested message")
    func tieVariant() async {
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition(isTie: true))])
        )

        await viewModel.load()

        #expect(viewModel.headline == String(localized: "recognition.tie"))
        #expect(viewModel.message == String(localized: "recognition.message.tie"))
    }

    @Test("CA-07 Kids read the same final result (UX-CA-04: no family data in the projection)")
    func kidsVariant() async {
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]),
            audience: .kid
        )

        await viewModel.load()

        #expect(viewModel.audience == .kid)
        #expect(viewModel.recognition?.points == 42)
        #expect(viewModel.message == String(localized: "recognition.message.first"))
    }

    @Test("UX-020 Erro: a failed first load offers retry, and retry fetches again")
    func errorAndRetry() async {
        let repository = RecognitionRepositorySpy(detail: [.failure(.network), .success(RecognitionFixtures.recognition())])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        #expect(viewModel.state == .error)

        await viewModel.load()
        #expect(viewModel.recognition != nil)
    }

    @Test("UX-020 Erro: a failed reload keeps the confirmed content and the edited message")
    func reloadFailureKeepsContent() async {
        let repository = RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition()), .failure(.unavailable)])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load()
        viewModel.message = "Bora fazer um piquenique?"

        await viewModel.load()

        #expect(viewModel.recognition != nil)
        #expect(viewModel.message == "Bora fazer um piquenique?")
    }

    @Test("CA-05/UX-020 Sessão inválida: recovers the session once and revalidates before showing")
    func recoversSession() async {
        let repository = RecognitionRepositorySpy(detail: [.failure(.sessionExpired), .success(RecognitionFixtures.recognition())])
        let session = RecognitionSessionStub(token: "stale", recoveredToken: "fresh")
        let viewModel = makeViewModel(repository: repository, session: session)

        await viewModel.load()

        #expect(session.recoveryCount == 1)
        #expect(repository.detailTokens == ["stale", "fresh"])
        #expect(viewModel.recognition != nil)
    }

    @Test("CA-05 an unrecoverable session never shows the result")
    func unrecoverableSession() async {
        let repository = RecognitionRepositorySpy(detail: [.failure(.sessionExpired)])
        let viewModel = makeViewModel(repository: repository, session: RecognitionSessionStub(token: "stale", recoveredToken: nil))

        await viewModel.load()

        #expect(viewModel.state == .sessionExpired)
        #expect(viewModel.recognition == nil)
    }

    @Test("SPEC-020 §5 records the first opening once, and its failure doesn't change the screen")
    func recordsOpeningOnce() async {
        let repository = RecognitionRepositorySpy(
            detail: [.success(RecognitionFixtures.recognition()), .success(RecognitionFixtures.recognition())],
            opening: [.failure(.unavailable)]
        )
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()

        #expect(repository.openedIDs == [RecognitionFixtures.id])
        #expect(viewModel.recognition != nil)
    }

    @Test("SPEC-020 §5 an already opened result is not reported again")
    func skipsOpeningWhenAlreadyOpened() async {
        let repository = RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition(openedAt: Date()))])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load()

        #expect(repository.openedIDs.isEmpty)
    }

    @Test("CA-08 nothing is shared until the explicit action, which sends the edited text")
    func sharesEditedTextOnlyOnAction() async {
        let sharing = HighlightSharingSpy()
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]),
            sharing: sharing
        )
        await viewModel.load()
        #expect(sharing.openedTexts.isEmpty)
        #expect(sharing.copiedTexts.isEmpty)

        viewModel.message = "Que tal um piquenique no domingo?"
        await viewModel.shareOnWhatsApp()

        #expect(sharing.openedTexts == ["Que tal um piquenique no domingo?"])
        // Returning or cancelling from WhatsApp never turns into a "sent" state.
        #expect(viewModel.recognition != nil)
        #expect(viewModel.showsWhatsAppAction)
    }

    @Test("CA-08 WhatsApp unavailable offers copying the message instead")
    func whatsAppUnavailable() async {
        let sharing = HighlightSharingSpy(canOpenWhatsApp: false)
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]),
            sharing: sharing
        )

        await viewModel.load()
        #expect(viewModel.isWhatsAppUnavailable)
        #expect(!viewModel.showsWhatsAppAction)

        viewModel.copyMessage()
        #expect(sharing.copiedTexts == [String(localized: "recognition.message.first")])
        #expect(viewModel.showsCopyConfirmation)
    }

    @Test("CA-08 a failed WhatsApp opening falls back to copy without claiming a send")
    func failedOpeningFallsBack() async {
        let sharing = HighlightSharingSpy()
        sharing.opensSucceed = false
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]),
            sharing: sharing
        )
        await viewModel.load()

        await viewModel.shareOnWhatsApp()

        #expect(viewModel.isWhatsAppUnavailable)
    }

    @Test("E-4 a blank message can't be shared nor copied")
    func blankMessageBlocksActions() async {
        let sharing = HighlightSharingSpy()
        let viewModel = makeViewModel(
            repository: RecognitionRepositorySpy(detail: [.success(RecognitionFixtures.recognition())]),
            sharing: sharing
        )
        await viewModel.load()
        viewModel.message = "   \n"

        await viewModel.shareOnWhatsApp()
        viewModel.copyMessage()

        #expect(!viewModel.canShare)
        #expect(sharing.openedTexts.isEmpty)
        #expect(sharing.copiedTexts.isEmpty)
        #expect(!viewModel.showsCopyConfirmation)
    }
}
