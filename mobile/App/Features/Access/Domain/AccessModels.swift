import Foundation

nonisolated enum MemberRole: String, Codable, Sendable, CaseIterable {
    case administrator
    case member
    case kid = "kids"

    /// The backend wire value is `kids`; `kid` is accepted defensively when decoding.
    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "administrator": self = .administrator
        case "member": self = .member
        case "kid", "kids": self = .kid
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown member role")
            )
        }
    }
}

nonisolated struct AppleAuthorizationProof: Sendable, Equatable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
}

nonisolated struct SessionToken: Sendable, Equatable {
    let accessToken: String
    let expiresAt: Date
}

nonisolated struct SessionCredentials: Sendable, Equatable {
    let token: SessionToken
    let refreshToken: String
}

nonisolated struct ActiveFamilySession: Sendable, Equatable, Hashable {
    let memberID: UUID
    let familyID: UUID
    let role: MemberRole
    let isFamilyCreator: Bool
}

nonisolated struct AuthenticatedSession: Sendable, Equatable {
    let sessionID: UUID
    let profile: ActiveFamilySession
    let credentials: SessionCredentials
}

nonisolated struct CreationGrant: Sendable, Equatable {
    let value: String
    let expiresAt: Date
}

nonisolated enum AppleSignInOutcome: Sendable, Equatable {
    case session(AuthenticatedSession)
    case creationGrant(CreationGrant)
}

nonisolated enum AccessError: Error, Sendable, Equatable {
    case appleProofInvalid
    case rateLimited
    case sessionExpired
    case sessionRevoked
    case network
    case invalidResponse
    case unavailable
}

nonisolated enum AppleAuthenticationError: Error, Sendable, Equatable {
    case cancelled
    case nativeFailure
}
