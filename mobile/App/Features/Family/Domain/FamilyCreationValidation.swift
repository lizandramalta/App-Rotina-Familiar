import Foundation

/// Local validation for the onboarding forms (SPEC-002 CA-02, RF48/RN63). The server stays the authority.
nonisolated enum FamilyCreationValidation {
    nonisolated enum TextError: Error, Equatable, Sendable {
        case required
        case invalidLength
        case invalidContent
    }

    static let defaultTimeZoneID = "America/Sao_Paulo"
    static let nameLimit = 60
    static let nicknameLimit = 20

    /// Control characters are checked on the raw text so a trailing line break is rejected, not trimmed away.
    static func validatedName(_ raw: String) -> Result<String, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.required)
        }
        guard trimmed.count <= nameLimit else {
            return .failure(.invalidLength)
        }
        return .success(trimmed)
    }

    static func validatedNickname(_ raw: String) -> Result<String?, TextError> {
        guard !containsControlCharacters(raw) else {
            return .failure(.invalidContent)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(nil)
        }
        guard trimmed.filter({ !$0.isWhitespace }).count <= nicknameLimit else {
            return .failure(.invalidLength)
        }
        return .success(trimmed)
    }

    static func isValidTimeZoneID(_ identifier: String) -> Bool {
        TimeZone.knownTimeZoneIdentifiers.contains(identifier)
    }

    /// General category Cc only. `CharacterSet.controlCharacters` also covers Cf (e.g. the ZWJ inside
    /// composite emoji), which would reject valid names such as "👨‍👩‍👧‍👦".
    private static func containsControlCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}
