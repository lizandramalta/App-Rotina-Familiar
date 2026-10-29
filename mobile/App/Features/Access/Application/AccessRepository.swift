import Foundation

nonisolated protocol AccessRepository: Sendable {
    func signIn(
        proof: AppleAuthorizationProof,
        installationProof: String
    ) async throws -> AppleSignInOutcome

    func currentSession(accessToken: String) async throws -> ActiveFamilySession

    func refresh(
        refreshToken: String,
        installationProof: String
    ) async throws -> SessionToken

    func revokeSession(accessToken: String) async throws
}

@MainActor
protocol AppleAuthenticating: AnyObject {
    func authorize() async throws -> AppleAuthorizationProof
}

protocol SessionCredentialStoring: Sendable {
    func refreshToken() throws -> String?
    func save(refreshToken: String) throws
    func clear() throws
}

protocol InstallationProofProviding: Sendable {
    func installationProof() throws -> String
}
