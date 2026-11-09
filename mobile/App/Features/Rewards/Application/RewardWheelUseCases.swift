import Foundation

/// Eligible catalog for TEL-024 (RN42): predefined items plus the family's own, in that order.
struct GetEligibleRewardsUseCase: Sendable {
    let repository: any RewardRepository

    func execute(accessToken: String) async throws -> [RewardItem] {
        let catalog = try await repository.rewardItems(accessToken: accessToken)
        return catalog.predefined + catalog.custom
    }
}

/// Local draw (RN43/RN52): unlimited, never persisted, never sent to the server.
struct DrawRewardUseCase: Sendable {
    let drawing: any RewardDrawing

    func execute(from items: [RewardItem]) -> Int? {
        guard !items.isEmpty else { return nil }
        return min(max(drawing.drawIndex(count: items.count), 0), items.count - 1)
    }
}

/// Sends the single acceptance (SPEC-017 §5.1). No automatic retry (§3.3).
struct AcceptRewardUseCase: Sendable {
    let repository: any MissionRepository

    func execute(missionID: UUID, rewardItemID: UUID, accessToken: String) async throws -> AcceptedMissionReward {
        try await repository.acceptReward(missionID: missionID, rewardItemID: rewardItemID, accessToken: accessToken)
    }
}

/// Reads the canonical mission before any new attempt (SPEC-017 §5.2, CA-07).
struct ReconcileRewardAcceptanceUseCase: Sendable {
    let repository: any MissionRepository

    func execute(missionID: UUID, chosenItemID: UUID?, accessToken: String) async throws -> RewardAcceptanceReconciliation {
        let detail: MissionDetail
        do {
            detail = try await repository.mission(id: missionID, accessToken: accessToken)
        } catch MissionError.notFound {
            return .unavailable
        }
        if let accepted = detail.acceptedReward {
            return accepted.rewardItemID == chosenItemID ? .acceptedByMe(accepted) : .acceptedByOther
        }
        if detail.status == .completed, detail.isRedemptionAvailable == true {
            return .stillAvailable
        }
        return .unavailable
    }
}
