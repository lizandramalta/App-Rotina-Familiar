import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-014 §5.1: title (1-60 visible chars) and note (<=250 chars) validation, same convention as Tasks.
struct MissionValidationTests {
    @Test("Rejects an empty or control-character-only title")
    func titleRequired() {
        #expect(MissionValidation.validatedTitle("") == .failure(.required))
        #expect(MissionValidation.validatedTitle("   ") == .failure(.required))
        #expect(MissionValidation.validatedTitle("\n") == .failure(.invalidContent))
    }

    @Test("Trims the title and rejects more than 60 visible characters")
    func titleLength() {
        let atLimit = String(repeating: "a", count: 60)
        let overLimit = String(repeating: "a", count: 61)

        #expect(MissionValidation.validatedTitle("  Arrumar o quintal  ") == .success("Arrumar o quintal"))
        #expect(MissionValidation.validatedTitle(atLimit) == .success(atLimit))
        #expect(MissionValidation.validatedTitle(overLimit) == .failure(.invalidLength))
    }

    @Test("RN68 allows an empty note (nil) and rejects more than 250 characters")
    func noteLength() {
        let atLimit = String(repeating: "a", count: 250)
        let overLimit = String(repeating: "a", count: 251)

        #expect(MissionValidation.validatedNote("") == .success(nil))
        #expect(MissionValidation.validatedNote("   ") == .success(nil))
        #expect(MissionValidation.validatedNote(atLimit) == .success(atLimit))
        #expect(MissionValidation.validatedNote(overLimit) == .failure(.invalidLength))
    }
}
