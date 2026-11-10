import Foundation

nonisolated enum RewardItemSource: String, Codable, Sendable, Equatable {
    case predefined
    case custom
}

/// SPEC-015 §5.2/§6 — `createdAt` is `nil` for the six predefined items, which don't belong to a
/// family (§6); only `custom` items carry it.
nonisolated struct RewardItem: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let details: String?
    let source: RewardItemSource
    let createdAt: Date?
}

/// `GET /v1/reward-items` (SPEC-015 §5.2) — predefined items plus only the family's own custom ones.
nonisolated struct RewardCatalog: Equatable, Sendable {
    let predefined: [RewardItem]
    let custom: [RewardItem]
}

nonisolated struct AddRewardItemCommand: Sendable {
    let title: String
    let details: String?
}

nonisolated enum RewardItemError: Error, Equatable, Sendable {
    case insufficientPermissions
    case validationFailed([String: [String]])
    case titleAlreadyExists
    /// The write may or may not have been persisted (no id to reconcile against, BA-07) — only
    /// `addRewardItem` throws this; the caller must reload the catalog to confirm (SPEC-015 §5.4/CA-07).
    case uncertainOutcome
    case network
    case unavailable
}
