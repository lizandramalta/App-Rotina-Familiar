import Foundation
@testable import FamilyRoutine
import Testing

/// SCRUM-126 Phase 4 — TEL-016 states (SPEC-013 CA-02–07, UX-013 §6).
@MainActor
struct KidsSignalDetailViewModelTests {
    private let id = UUID()

    private func detail() -> KidsSignalDetail {
        KidsSignalDetail(
            id: id, taskID: UUID(), taskTitle: "Arrumar a cama", childName: "Rafa",
            signaledAt: Date(timeIntervalSince1970: 1_800_000_000), assignees: ["Rafa"], photoMediaID: nil
        )
    }

    private func makeViewModel(_ repository: KidsSignalDetailRepositoryStub) -> KidsSignalDetailViewModel {
        KidsSignalDetailViewModel(id: id, repository: repository, accessTokenProvider: { "token-1" })
    }

    @Test("UX-013 §6 a failed decision keeps the detail on screen and reports the error")
    func failedDecisionKeepsDetail() async {
        let repository = KidsSignalDetailRepositoryStub(details: [.success(detail()), .success(detail())])
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.decide(.confirm)

        #expect(viewModel.failed)
        #expect(viewModel.detail?.taskTitle == "Arrumar a cama")
        #expect(!viewModel.resolved)
        #expect(!viewModel.isDeciding)
    }

    @Test("UX-013 §5.2 a successful decision, even late (applied: false), resolves silently")
    func successfulDecisionResolves() async {
        let repository = KidsSignalDetailRepositoryStub(
            details: [.success(detail())],
            decision: .success(KidsDecisionResult(taskStatus: .completed, outcome: "confirmed", applied: false))
        )
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.decide(.confirm)

        #expect(viewModel.resolved)
        #expect(viewModel.detail == nil)
        #expect(!viewModel.failed)
    }

    @Test("UX-013 §6 a lost response whose signal is gone reconciles as resolved")
    func lostResponseReconciles() async {
        let repository = KidsSignalDetailRepositoryStub(details: [.success(detail()), .failure(KidsSignalError.notFound)])
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.decide(.reject)

        #expect(viewModel.resolved)
        #expect(!viewModel.failed)
    }

    @Test("UX-013 §4 / SCRUM-117 a signal already settled by someone else returns silently (no static screen)")
    func notFoundOnFirstLoadReturnsSilently() async {
        let viewModel = makeViewModel(KidsSignalDetailRepositoryStub(details: [.failure(KidsSignalError.notFound)]))

        await viewModel.load()

        #expect(viewModel.resolved)
        #expect(!viewModel.failed)
        #expect(viewModel.detail == nil)
    }

    @Test("UX-013 §6 a signal decided elsewhere while open reconciles silently on reload")
    func notFoundAfterLoadResolves() async {
        let repository = KidsSignalDetailRepositoryStub(details: [.success(detail()), .failure(KidsSignalError.notFound)])
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.load()

        #expect(viewModel.resolved)
    }

    @Test("UX-013 §8 the private photo viewer clamps pinch zoom and double-tap toggles 1× and 2.5×")
    func photoViewerZoom() {
        #expect(KidsPrivatePhotoViewer.clamped(0.3) == 1)
        #expect(KidsPrivatePhotoViewer.clamped(9) == 4)
        #expect(KidsPrivatePhotoViewer.toggledScale(from: 1) == 2.5)
        #expect(KidsPrivatePhotoViewer.toggledScale(from: 2.5) == 1)
    }

    @Test("Figma 870:27317 the enlarged photo caption names task, child and date")
    func photoCaption() {
        let caption = KidsSignalDetailView.photoCaption(detail())
        #expect(caption.hasPrefix("Arrumar a cama · Rafa · "))
    }

    @Test("UX-013 §5.2 taskNote defaults to nil and is carried when present")
    func taskNoteDefaults() {
        #expect(detail().taskNote == nil)
        let withNote = KidsSignalDetail(
            id: id, taskID: UUID(), taskTitle: "T", childName: "C", signaledAt: .now,
            assignees: [], photoMediaID: nil, taskNote: "Observação"
        )
        #expect(withNote.taskNote == "Observação")
    }

}

final class KidsSignalDetailRepositoryStub: KidsSignalRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var details: [Result<KidsSignalDetail, Error>]
    private let decision: Result<KidsDecisionResult, Error>

    init(
        details: [Result<KidsSignalDetail, Error>],
        decision: Result<KidsDecisionResult, Error> = .failure(KidsSignalError.network)
    ) {
        self.details = details
        self.decision = decision
    }

    func getReviewQueue(accessToken: String, cursor: String?) async throws -> KidsReviewQueuePage {
        KidsReviewQueuePage(items: [], nextCursor: nil)
    }

    func getSignalDetail(id: UUID, accessToken: String) async throws -> KidsSignalDetail {
        try lock.withLock {
            guard !details.isEmpty else { throw KidsSignalError.unavailable }
            return try details.removeFirst().get()
        }
    }

    func decideSignal(id: UUID, decision: KidsReviewDecision, accessToken: String) async throws -> KidsDecisionResult {
        try self.decision.get()
    }

    func getSignalPhoto(mediaID: UUID, accessToken: String) async throws -> Data {
        throw KidsSignalError.unavailable
    }
}
