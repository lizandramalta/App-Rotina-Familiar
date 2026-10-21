import Foundation

nonisolated protocol InviteJoinRepository: Sendable {
    func inspect(token: String) async throws
    func join(
        token: String,
        password: String,
        attempt: InviteJoinAttempt,
        switchConfirmed: Bool,
        previousAccessToken: String?
    ) async throws -> AuthenticatedSession
    func recover(attempt: InviteJoinAttempt) async throws -> AuthenticatedSession
}

nonisolated protocol InviteJoinAttemptStoring: Sendable {
    func pendingAttempt() throws -> InviteJoinAttempt?
    func save(_ attempt: InviteJoinAttempt) throws
    func clear() throws
}
