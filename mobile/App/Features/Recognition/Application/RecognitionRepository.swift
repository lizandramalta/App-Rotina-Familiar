import Foundation

/// Own weekly recognitions (`/v1/me/weekly-recognitions`, SPEC-020 §5). Only the session owner's results.
nonisolated protocol RecognitionRepository: Sendable {
    /// Finalized results of the owner, most recent cycle first.
    func listOwn(accessToken: String) async throws -> [WeeklyRecognition]
    func recognition(id: UUID, accessToken: String) async throws -> WeeklyRecognition
    /// Monotonic first opening. It never claims reading nor sending (SPEC-020 §5).
    func recordOpening(id: UUID, accessToken: String) async throws -> WeeklyRecognition
}

/// Local, human-triggered sharing (RF64). Nothing here reports whether a message was sent.
@MainActor
protocol HighlightSharing: AnyObject {
    var canOpenWhatsApp: Bool { get }
    /// Hands the editable text to WhatsApp. `true` only means the app could be opened.
    func openWhatsApp(text: String) async -> Bool
    func copy(text: String)
}

/// Session access used by TEL-052: the current token and the recovery path for an invalid session.
@MainActor
protocol RecognitionSessionProviding: AnyObject {
    var currentAccessToken: String? { get }
    /// Tries to recover the session (refresh). Returns the new token, or `nil` when the person must sign in again.
    func recoverAccessToken() async -> String?
}
