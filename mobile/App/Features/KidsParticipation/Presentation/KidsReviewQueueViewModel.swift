import Foundation
import Observation

/// TEL-015 — Confirmações Kids (SPEC-013 Phase 2, UX-013 §5.1). Read-only queue of pending signals, oldest first.
@MainActor
@Observable
final class KidsReviewQueueViewModel {
    enum ViewState: Equatable {
        case loading
        case content
        case empty
        case failed
    }

    private(set) var items: [KidsSignalSummary] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var loadFailed = false
    private(set) var loadMoreFailed = false
    /// Becomes `true` after the first attempt settles, so the first load never presents as an empty queue.
    private var hasLoaded = false

    private let repository: any KidsSignalRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(repository: any KidsSignalRepository, accessTokenProvider: @escaping @MainActor () -> String?) {
        self.repository = repository
        self.accessTokenProvider = accessTokenProvider
    }

    var viewState: ViewState {
        if !items.isEmpty { return .content }
        if loadFailed { return .failed }
        if isLoading || !hasLoaded { return .loading }
        return .empty
    }

    /// A failed reload keeps the confirmed items; only a queue that never loaded shows the failure state.
    func load() async {
        guard !isLoading else { return }
        loadFailed = false
        guard let token = accessTokenProvider() else {
            loadFailed = true
            hasLoaded = true
            return
        }

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            let page = try await repository.getReviewQueue(accessToken: token, cursor: nil)
            items = page.items
            nextCursor = page.nextCursor
            loadMoreFailed = false
        } catch {
            loadFailed = true
        }
    }

    func loadMoreIfNeeded(currentItem: KidsSignalSummary) async {
        guard currentItem.id == items.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoading, !isLoadingMore, let token = accessTokenProvider() else { return }
        loadMoreFailed = false
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await repository.getReviewQueue(accessToken: token, cursor: cursor)
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
        } catch {
            loadMoreFailed = true
        }
    }
}
