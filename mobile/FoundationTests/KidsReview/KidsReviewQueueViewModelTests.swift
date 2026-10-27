import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct KidsReviewQueueViewModelTests {
    private func signal(_ title: String) -> KidsSignalSummary {
        KidsSignalSummary(
            id: UUID(),
            taskID: UUID(),
            taskTitle: title,
            signaledByID: UUID(),
            childName: "Rafa",
            signaledAt: Date(timeIntervalSince1970: 1_800_000_000),
            hasPhoto: false
        )
    }

    private func makeViewModel(
        _ results: [Result<KidsReviewQueuePage, Error>],
        token: String? = "token-1"
    ) -> (KidsReviewQueueViewModel, KidsSignalRepositorySpy) {
        let repository = KidsSignalRepositorySpy(results: results)
        return (KidsReviewQueueViewModel(repository: repository, accessTokenProvider: { token }), repository)
    }

    @Test("SPEC-013 CA-01 starts loading and never presents the first load as empty")
    func startsLoading() {
        let (viewModel, _) = makeViewModel([])

        #expect(viewModel.viewState == .loading)
    }

    @Test("SPEC-013 CA-01 shows the pending signals in the server order")
    func showsContent() async {
        let first = signal("A")
        let second = signal("B")
        let (viewModel, repository) = makeViewModel([.success(KidsReviewQueuePage(items: [first, second], nextCursor: nil))])

        await viewModel.load()

        #expect(viewModel.viewState == .content)
        #expect(viewModel.items == [first, second])
        #expect(repository.requestedCursors == [nil])
        #expect(repository.requestedTokens == ["token-1"])
    }

    @Test("SPEC-013 an empty queue shows the empty state")
    func showsEmpty() async {
        let (viewModel, _) = makeViewModel([.success(KidsReviewQueuePage(items: [], nextCursor: nil))])

        await viewModel.load()

        #expect(viewModel.viewState == .empty)
    }

    @Test("SPEC-013 a failed first load shows the failure state and retry recovers")
    func failureThenRetry() async {
        let item = signal("A")
        let (viewModel, _) = makeViewModel([
            .failure(KidsSignalError.network),
            .success(KidsReviewQueuePage(items: [item], nextCursor: nil)),
        ])

        await viewModel.load()
        #expect(viewModel.viewState == .failed)

        await viewModel.load()
        #expect(viewModel.viewState == .content)
        #expect(viewModel.items == [item])
    }

    @Test("SPEC-013 a failed reload keeps the confirmed items")
    func reloadFailureKeepsItems() async {
        let item = signal("A")
        let (viewModel, _) = makeViewModel([
            .success(KidsReviewQueuePage(items: [item], nextCursor: nil)),
            .failure(KidsSignalError.unavailable),
        ])
        await viewModel.load()

        await viewModel.load()

        #expect(viewModel.viewState == .content)
        #expect(viewModel.items == [item])
    }

    @Test("SPEC-013 without an access token nothing is requested")
    func missingToken() async {
        let (viewModel, repository) = makeViewModel([], token: nil)

        await viewModel.load()

        #expect(viewModel.viewState == .failed)
        #expect(repository.requestedCursors.isEmpty)
    }

    @Test("SPEC-013 CA-01 the last item loads the next page with the cursor and skips duplicates")
    func paginates() async {
        let first = signal("A")
        let second = signal("B")
        let (viewModel, repository) = makeViewModel([
            .success(KidsReviewQueuePage(items: [first], nextCursor: "c2")),
            .success(KidsReviewQueuePage(items: [first, second], nextCursor: nil)),
        ])
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(currentItem: second)
        #expect(repository.requestedCursors == [nil])

        await viewModel.loadMoreIfNeeded(currentItem: first)

        #expect(repository.requestedCursors == [nil, "c2"])
        #expect(viewModel.items == [first, second])
        #expect(viewModel.nextCursor == nil)
    }

    @Test("SPEC-013 a failed page keeps the items and allows a retry")
    func loadMoreFailure() async {
        let first = signal("A")
        let second = signal("B")
        let (viewModel, _) = makeViewModel([
            .success(KidsReviewQueuePage(items: [first], nextCursor: "c2")),
            .failure(KidsSignalError.network),
            .success(KidsReviewQueuePage(items: [second], nextCursor: nil)),
        ])
        await viewModel.load()

        await viewModel.loadMore()
        #expect(viewModel.loadMoreFailed)
        #expect(viewModel.items == [first])

        await viewModel.loadMore()
        #expect(!viewModel.loadMoreFailed)
        #expect(viewModel.items == [first, second])
    }
}

final class KidsSignalRepositorySpy: KidsSignalRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<KidsReviewQueuePage, Error>]
    private var cursors: [String?] = []
    private var tokens: [String] = []

    init(results: [Result<KidsReviewQueuePage, Error>]) {
        self.results = results
    }

    var requestedCursors: [String?] { lock.withLock { cursors } }
    var requestedTokens: [String] { lock.withLock { tokens } }

    func getReviewQueue(accessToken: String, cursor: String?) async throws -> KidsReviewQueuePage {
        try lock.withLock {
            cursors.append(cursor)
            tokens.append(accessToken)
            guard !results.isEmpty else { return KidsReviewQueuePage(items: [], nextCursor: nil) }
            return try results.removeFirst().get()
        }
    }
}
