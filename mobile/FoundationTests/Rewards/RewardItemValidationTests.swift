import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-015 §5.1: title (60 non-whitespace chars after trim) and details (<=255 chars, counting
/// whitespace) validation, mirroring `backend/src/modules/rewards/domain/reward-validation.ts`.
struct RewardItemValidationTests {
    @Test("Rejects an empty or control-character-only title")
    func titleRequired() {
        #expect(RewardItemValidation.validatedTitle("") == .failure(.required))
        #expect(RewardItemValidation.validatedTitle("   ") == .failure(.required))
        #expect(RewardItemValidation.validatedTitle("\n") == .failure(.invalidContent))
    }

    @Test("Trims the title and counts only non-whitespace characters toward the 60-character limit")
    func titleLength() {
        let atLimit = String(repeating: "a", count: 60)
        let overLimit = String(repeating: "a", count: 61)
        // An internal space survives the trim but doesn't count toward the limit (UX-015 §5.2's
        // `{{current}}/60`), unlike `MissionValidation`, which counts every trimmed character.
        let atLimitWithInternalSpace = String(repeating: "a", count: 30) + " " + String(repeating: "a", count: 30)
        let overLimitWithInternalSpace = String(repeating: "a", count: 30) + " " + String(repeating: "a", count: 31)

        #expect(RewardItemValidation.validatedTitle("  Noite de pizza  ") == .success("Noite de pizza"))
        #expect(RewardItemValidation.validatedTitle(atLimit) == .success(atLimit))
        #expect(RewardItemValidation.validatedTitle(atLimitWithInternalSpace) == .success(atLimitWithInternalSpace))
        #expect(RewardItemValidation.validatedTitle(overLimit) == .failure(.invalidLength))
        #expect(RewardItemValidation.validatedTitle(overLimitWithInternalSpace) == .failure(.invalidLength))
    }

    @Test("Allows an empty details (nil) and rejects more than 255 characters, counting whitespace")
    func detailsLength() {
        let atLimit = String(repeating: "a", count: 255)
        let overLimit = String(repeating: "a", count: 256)
        let spacedOverLimit = String(repeating: "a", count: 250) + "      "

        #expect(RewardItemValidation.validatedDetails("") == .success(nil))
        #expect(RewardItemValidation.validatedDetails("   ") == .success(nil))
        #expect(RewardItemValidation.validatedDetails(atLimit) == .success(atLimit))
        #expect(RewardItemValidation.validatedDetails(overLimit) == .failure(.invalidLength))
        #expect(RewardItemValidation.validatedDetails(spacedOverLimit) == .failure(.invalidLength))
    }
}
