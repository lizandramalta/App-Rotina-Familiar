import Foundation

/// Local validation mirroring the backend contract (SPEC-015 §5.1 / `reward-validation.ts`), for
/// instant field feedback. The server stays the authority.
nonisolated enum RewardItemValidation {
    nonisolated enum TextError: Error, Equatable, Sendable {
        case required
        case invalidLength
        case invalidContent
    }

    /// Non-whitespace characters only (UX-015 §5.2's `{{current}}/60` counter), unlike
    /// `MissionValidation.titleLimit`, which counts every trimmed character.
    static let titleLimit = 60
    /// Counts every character, including whitespace (UX-015 §5.2's `{{current}}/255` counter).
    static let detailsLimit = 255

    /// Control characters are checked on the raw text so a trailing line break is rejected, not trimmed away.
    static func validatedTitle(_ raw: String) -> Result<String, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.required)
        }
        guard trimmed.filter({ !$0.isWhitespace }).count <= titleLimit else {
            return .failure(.invalidLength)
        }
        return .success(trimmed)
    }

    /// Empty after trim means "sem descrição": sent as `nil`, never blocked as invalid.
    static func validatedDetails(_ raw: String) -> Result<String?, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(nil)
        }
        guard raw.count <= detailsLimit else {
            return .failure(.invalidLength)
        }
        return .success(raw)
    }

    private static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}
