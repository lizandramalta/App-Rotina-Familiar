import Foundation

/// SPEC-015 Fase 1 — catálogo coletivo. Administrador apenas; família vem exclusivamente da sessão.
nonisolated protocol RewardRepository: Sendable {
    func rewardItems(accessToken: String) async throws -> RewardCatalog
    func addRewardItem(_ command: AddRewardItemCommand, accessToken: String) async throws -> RewardItem
}
