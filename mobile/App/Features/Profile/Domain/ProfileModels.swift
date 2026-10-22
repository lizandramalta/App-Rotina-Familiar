import Foundation

/// Cumulative mission-participation milestones (RN64): bronze 5, silver 10, gold 25, diamond 50.
nonisolated enum BadgeTier: String, Codable, CaseIterable, Comparable, Equatable, Hashable, Sendable {
    case bronze
    case silver
    case gold
    case diamond

    var requiredMissionCount: Int {
        switch self {
        case .bronze: 5
        case .silver: 10
        case .gold: 25
        case .diamond: 50
        }
    }

    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        lhs.requiredMissionCount < rhs.requiredMissionCount
    }
}

nonisolated struct NextBadgeTier: Equatable, Sendable {
    let code: BadgeTier
    let requiredMissionCount: Int
    let remaining: Int
}

nonisolated struct OwnProfile: Equatable, Sendable {
    let memberID: UUID
    let name: String
    let familyName: String
    let nickname: String?
    let photoMediaID: String?
    let totalParticipations: Int
    /// `nil` once the member reached diamond.
    let nextTier: NextBadgeTier?
}

nonisolated struct BadgeAward: Identifiable, Equatable, Hashable, Sendable {
    let awardID: UUID
    let tier: BadgeTier
    let requiredMissionCount: Int
    let awardedAt: Date

    var id: UUID { awardID }
}

nonisolated struct BadgesOverview: Equatable, Sendable {
    let totalParticipations: Int
    let nextTier: NextBadgeTier?
    let awards: [BadgeAward]
}

/// One of the four fixed milestones as TEL-030 shows it (conquered, next target or plain pending).
nonisolated struct BadgeDisplayItem: Identifiable, Equatable, Hashable, Sendable {
    let tier: BadgeTier
    let requiredMissionCount: Int
    let awardID: UUID?
    let awardedAt: Date?
    let isConquered: Bool
    let isNextTarget: Bool

    var id: BadgeTier { tier }
}

extension BadgesOverview {
    /// Always the four fixed milestones, in order; never simulates a conquest (SPEC-006 CA-10).
    nonisolated func displayItems() -> [BadgeDisplayItem] {
        BadgeTier.allCases.map { tier in
            let award = awards.first { $0.tier == tier }
            return BadgeDisplayItem(
                tier: tier,
                requiredMissionCount: tier.requiredMissionCount,
                awardID: award?.awardID,
                awardedAt: award?.awardedAt,
                isConquered: award != nil,
                isNextTarget: nextTier?.code == tier
            )
        }
    }
}

nonisolated struct ContributingMission: Identifiable, Equatable, Hashable, Sendable {
    let missionID: UUID
    let title: String
    let completedAt: Date

    var id: UUID { missionID }
}

nonisolated struct BadgeDetail: Equatable, Sendable {
    let awardID: UUID
    let tier: BadgeTier
    let awardedAt: Date
    let contributingMissions: [ContributingMission]
}

/// Partial update of a nullable profile field: leave as is, set a value, or remove it.
nonisolated enum OptionalFieldUpdate<Value: Equatable & Sendable>: Equatable, Sendable {
    case unchanged
    case set(Value)
    case clear
}

nonisolated struct UpdateOwnProfileCommand: Equatable, Sendable {
    /// Adults only (SPEC-006 E-05); `nil` leaves the name untouched.
    var name: String?
    var nickname: OptionalFieldUpdate<String>
    var photoMediaID: OptionalFieldUpdate<String>

    init(
        name: String? = nil,
        nickname: OptionalFieldUpdate<String> = .unchanged,
        photoMediaID: OptionalFieldUpdate<String> = .unchanged
    ) {
        self.name = name
        self.nickname = nickname
        self.photoMediaID = photoMediaID
    }
}

nonisolated enum ProfileError: Error, Equatable, Sendable {
    case unauthorized
    case actionNotAllowed
    case notFound
    case mediaTooLarge
    case mediaFormatUnsupported
    /// `fieldErrors` keyed by wire field (`name`, `nickname`, `photoMediaId`).
    case validationFailed([String: [String]])
    case rateLimited
    /// Definitive 4xx refusal not covered by a more specific case.
    case rejected
    case network
    case unavailable
}
