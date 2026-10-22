import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-007 CA-04/CA-16: title (1-60 visible chars) and note (<=250 chars) validation.
struct TaskValidationTests {
    @Test("CA-04 rejects an empty or control-character-only title")
    func titleRequired() {
        #expect(TaskValidation.validatedTitle("") == .failure(.required))
        #expect(TaskValidation.validatedTitle("   ") == .failure(.required))
        #expect(TaskValidation.validatedTitle("\n") == .failure(.invalidContent))
    }

    @Test("CA-04 trims the title and rejects more than 60 visible characters")
    func titleLength() {
        let atLimit = String(repeating: "a", count: 60)
        let overLimit = String(repeating: "a", count: 61)

        #expect(TaskValidation.validatedTitle("  Arrumar a cama  ") == .success("Arrumar a cama"))
        #expect(TaskValidation.validatedTitle(atLimit) == .success(atLimit))
        #expect(TaskValidation.validatedTitle(overLimit) == .failure(.invalidLength))
    }

    @Test("CA-16 allows an empty note (nil) and rejects more than 250 characters")
    func noteLength() {
        let atLimit = String(repeating: "a", count: 250)
        let overLimit = String(repeating: "a", count: 251)

        #expect(TaskValidation.validatedNote("") == .success(nil))
        #expect(TaskValidation.validatedNote("   ") == .success(nil))
        #expect(TaskValidation.validatedNote(atLimit) == .success(atLimit))
        #expect(TaskValidation.validatedNote(overLimit) == .failure(.invalidLength))
    }
}
