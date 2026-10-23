import Foundation

nonisolated struct DraftMember: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var role: MemberRole
}

/// Local onboarding draft (TEL-055/TEL-002/TEL-033). Lives in memory only until the family exists.
nonisolated struct OnboardingDraft: Equatable, Sendable {
    var name = ""
    var nickname = ""
    var photo: Data?
    var familyName = ""
    var timeZoneID = FamilyCreationValidation.defaultTimeZoneID
    var members: [DraftMember] = []
}

nonisolated struct CreateFamilyCommand: Equatable, Sendable {
    let creationGrant: String
    let creatorName: String
    let creatorNickname: String?
    let familyName: String
    let timeZoneID: String
}

nonisolated struct CreatedFamily: Equatable, Sendable {
    let familyID: UUID
    let name: String
    let timeZoneID: String
    let session: AuthenticatedSession
}

nonisolated struct CreatedMember: Equatable, Sendable {
    let id: UUID
    let name: String
    let role: MemberRole
}

nonisolated struct MemberInvite: Equatable, Sendable {
    let inviteID: UUID
    let link: String
    let password: String
}

/// `GET /v1/family/members` row — consumed by Tasks' assignee picker (MOD-001).
nonisolated struct FamilyMember: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let role: MemberRole
    let isFamilyCreator: Bool
}

nonisolated struct MemberCapabilities: Equatable, Sendable {
    let manageMembers: Bool
}

/// `GET /v1/family/members/{memberId}` — member detail with the caller's capabilities (SPEC-003).
nonisolated struct FamilyMemberDetail: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let role: MemberRole
    let isFamilyCreator: Bool
    let createdAt: String
    let capabilities: MemberCapabilities
}

nonisolated struct FamilyMemberPage: Equatable, Sendable {
    let items: [FamilyMember]
    let nextCursor: String?
}

// MARK: - Family Settings (SPEC-002 Phase 3)

nonisolated enum TimeZoneApplication: String, Codable, Equatable, Sendable {
    case immediate
    case nextCycle
}

nonisolated struct CycleLimits: Equatable, Sendable {
    let startsAt: String
    let endsAt: String
    let timeZoneID: String
    let isTransition: Bool
}

nonisolated struct ScheduledTimeZoneChange: Equatable, Sendable {
    let timeZoneID: String
    let effectiveAt: String
}

nonisolated struct FamilySettings: Equatable, Sendable {
    let timeZoneID: String
    let scheduledTimeZoneChange: ScheduledTimeZoneChange?
    let limits: CycleLimits
}

nonisolated struct TimeZoneChangePreview: Equatable, Sendable {
    let proposedTimeZoneID: String
    let application: TimeZoneApplication
    let effectiveAt: String
    let effectiveLimits: CycleLimits
    let isTransition: Bool
}

nonisolated enum FamilyError: Error, Equatable, Sendable {
    case creationGrantInvalid
    case validationFailed([String: [String]])
    case actionNotAllowed
    case timeZoneUnchanged
    case rateLimited
    /// The request may or may not have been persisted; callers must not retry automatically.
    case uncertainOutcome
    /// Definitive 4xx refusal not covered by a more specific case.
    case rejected
    case network
    case unavailable
}
