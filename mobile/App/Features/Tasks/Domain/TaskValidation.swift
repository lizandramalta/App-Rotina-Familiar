import Foundation

/// Local validation mirroring the backend contract (SPEC-007 CA-04/CA-16), for instant field
/// feedback. The server stays the authority.
nonisolated enum TaskValidation {
    nonisolated enum TextError: Error, Equatable, Sendable {
        case required
        case invalidLength
        case invalidContent
    }

    static let titleLimit = 60
    static let noteLimit = 250

    /// Control characters are checked on the raw text so a trailing line break is rejected, not trimmed away.
    static func validatedTitle(_ raw: String) -> Result<String, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.required)
        }
        guard trimmed.count <= titleLimit else {
            return .failure(.invalidLength)
        }
        return .success(trimmed)
    }

    /// Empty after trim means "no note": sent as `nil` to clear it, never blocked as invalid.
    static func validatedNote(_ raw: String) -> Result<String?, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(nil)
        }
        guard trimmed.count <= noteLimit else {
            return .failure(.invalidLength)
        }
        return .success(trimmed)
    }

    private static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}
