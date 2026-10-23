import Foundation

/// Local validation for MOD-009 (SPEC-006 CA-06/CA-13, RF02/RN63). Same rules as onboarding; the server stays the authority.
nonisolated enum ProfileValidation {
    static func validatedName(_ raw: String) -> Result<String, FamilyCreationValidation.TextError> {
        FamilyCreationValidation.validatedName(raw)
    }

    /// An empty nickname (after trim) removes the setting, so it validates to `nil`.
    static func validatedNickname(_ raw: String) -> Result<String?, FamilyCreationValidation.TextError> {
        FamilyCreationValidation.validatedNickname(raw)
    }

    /// Counter shown next to the nickname field: non-space characters of the trimmed text.
    static func nonWhitespaceCount(_ raw: String) -> Int {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isWhitespace }.count
    }
}
