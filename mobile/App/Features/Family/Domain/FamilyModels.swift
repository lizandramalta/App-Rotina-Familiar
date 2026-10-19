import Foundation

nonisolated struct DraftMember: Identifiable, Equatable, Sendable {
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

nonisolated enum FamilyError: Error, Equatable, Sendable {
    case creationGrantInvalid
    case validationFailed([String: [String]])
    case rateLimited
    /// The request may or may not have been persisted; callers must not retry automatically.
    case uncertainOutcome
    /// Definitive 4xx refusal not covered by a more specific case.
    case rejected
    case network
    case unavailable
}
