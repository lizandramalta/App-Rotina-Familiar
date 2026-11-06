import Foundation
@testable import FamilyRoutine

let rewardRepositorySpyFixture = RewardItem(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f6")!,
    title: "Noite de pizza",
    details: "Escolher juntos o sabor e o filme",
    source: .custom,
    createdAt: Date(timeIntervalSince1970: 1_760_000_000)
)

/// A lock-protected class rather than an actor, matching `MissionRepositorySpy`'s existing pattern:
/// avoids `await` at every call site in tests that are themselves `@MainActor`-isolated.
final class RewardRepositorySpy: RewardRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var rewardItemsResult: Result<RewardCatalog, Error>
    private var addResult: Result<RewardItem, Error>

    private var _addCalls: [AddRewardItemCommand] = []
    var addCalls: [AddRewardItemCommand] { lock.withLock { _addCalls } }

    init(
        rewardItemsResult: Result<RewardCatalog, Error> = .success(RewardCatalog(predefined: [], custom: [])),
        addResult: Result<RewardItem, Error> = .success(rewardRepositorySpyFixture)
    ) {
        self.rewardItemsResult = rewardItemsResult
        self.addResult = addResult
    }

    static var fixture: RewardItem { rewardRepositorySpyFixture }

    func rewardItems(accessToken: String) async throws -> RewardCatalog {
        try rewardItemsResult.get()
    }

    func addRewardItem(_ command: AddRewardItemCommand, accessToken: String) async throws -> RewardItem {
        lock.withLock { _addCalls.append(command) }
        return try addResult.get()
    }

    func setRewardItemsResult(_ result: Result<RewardCatalog, Error>) {
        lock.withLock { rewardItemsResult = result }
    }

    func setAddResult(_ result: Result<RewardItem, Error>) {
        lock.withLock { addResult = result }
    }
}
