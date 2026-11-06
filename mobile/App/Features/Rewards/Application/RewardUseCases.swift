import Foundation

struct GetRewardItemsUseCase: Sendable {
    let repository: any RewardRepository

    func execute(accessToken: String) async throws -> RewardCatalog {
        try await repository.rewardItems(accessToken: accessToken)
    }
}

struct AddRewardItemUseCase: Sendable {
    let repository: any RewardRepository

    func execute(_ command: AddRewardItemCommand, accessToken: String) async throws -> RewardItem {
        try await repository.addRewardItem(command, accessToken: accessToken)
    }
}
