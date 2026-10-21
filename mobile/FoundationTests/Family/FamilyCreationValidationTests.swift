import Foundation
@testable import FamilyRoutine
import Testing

struct FamilyCreationValidationTests {
    private let familyEmoji = "👨‍👩‍👧‍👦"

    @Test("SPEC-002 CA-02 counts extended grapheme clusters, not scalars")
    func compositeEmojiCountsAsOneCharacter() {
        let atLimit = String(repeating: familyEmoji, count: 60)
        let overLimit = String(repeating: familyEmoji, count: 61)

        #expect(FamilyCreationValidation.validatedName(atLimit) == .success(atLimit))
        #expect(FamilyCreationValidation.validatedName(overLimit) == .failure(.invalidLength))
    }

    @Test("SPEC-002 CA-02 rejects empty or whitespace-only names")
    func blankNameIsRequired() {
        #expect(FamilyCreationValidation.validatedName("") == .failure(.required))
        #expect(FamilyCreationValidation.validatedName("   ") == .failure(.required))
    }

    @Test("SPEC-002 CA-02 trims surrounding spaces before storing the name")
    func nameIsTrimmed() {
        #expect(FamilyCreationValidation.validatedName("  Casa Silva ") == .success("Casa Silva"))
    }

    @Test("SPEC-002 CA-02 rejects control characters on the raw text, before trimming", arguments: [
        "Casa\nSilva", "Casa Silva\n", "\rCasa", "Casa\tSilva", "Casa\u{0}Silva",
    ])
    func controlCharactersAreInvalidContent(raw: String) {
        #expect(FamilyCreationValidation.validatedName(raw) == .failure(.invalidContent))
        #expect(FamilyCreationValidation.validatedNickname(raw) == .failure(.invalidContent))
    }

    @Test("RF48 nickname is optional and blank becomes nil")
    func blankNicknameIsNil() {
        #expect(FamilyCreationValidation.validatedNickname("") == .success(nil))
        #expect(FamilyCreationValidation.validatedNickname("   ") == .success(nil))
    }

    @Test("RF48 nickname limit counts only non-whitespace visible characters")
    func nicknameLimitIgnoresWhitespace() {
        let twentyVisibleWithSpaces = "abcde fghij klmno pqrst"
        let twentyOneVisible = String(repeating: "a", count: 21)

        #expect(FamilyCreationValidation.validatedNickname(twentyVisibleWithSpaces) == .success(twentyVisibleWithSpaces))
        #expect(FamilyCreationValidation.validatedNickname(twentyOneVisible) == .failure(.invalidLength))
    }

    @Test("SPEC-002 CA-02 validates IANA identifiers and defaults to America/Sao_Paulo")
    func timeZoneValidation() {
        #expect(FamilyCreationValidation.defaultTimeZoneID == "America/Sao_Paulo")
        #expect(FamilyCreationValidation.isValidTimeZoneID("America/Sao_Paulo"))
        #expect(FamilyCreationValidation.isValidTimeZoneID("Europe/Lisbon"))
        #expect(!FamilyCreationValidation.isValidTimeZoneID("Mars/Olympus"))
        #expect(!FamilyCreationValidation.isValidTimeZoneID(""))
    }
}
