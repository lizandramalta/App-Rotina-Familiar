import Foundation

enum MemberRole: String, Codable, Sendable {
    case administrator
    case member
    case kid
}

struct AppleAuthorizationProof: Sendable, Equatable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
}

struct SessionToken: Sendable, Equatable {
    let accessToken: String
    let expiresAt: Date
}

struct SessionCredentials: Sendable, Equatable {
    let token: SessionToken
    let refreshToken: String
}

struct ActiveFamilySession: Sendable, Equatable {
    let memberID: UUID
    let familyID: UUID
    let role: MemberRole
    let isFamilyCreator: Bool
}

struct AuthenticatedSession: Sendable, Equatable {
    let sessionID: UUID
    let profile: ActiveFamilySession
    let credentials: SessionCredentials
}

struct CreationGrant: Sendable, Equatable {
    let value: String
    let expiresAt: Date
}

enum AppleSignInOutcome: Sendable, Equatable {
    case session(AuthenticatedSession)
    case creationGrant(CreationGrant)
}

enum AccessError: Error, Sendable, Equatable {
    case appleProofInvalid
    case rateLimited
    case sessionExpired
    case sessionRevoked
    case network
    case invalidResponse
    case unavailable
}

enum AppleAuthenticationError: Error, Sendable, Equatable {
    case cancelled
    case nativeFailure
}
