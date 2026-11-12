import Foundation
@testable import FamilyRoutine
import Testing

/// SCRUM-113 — TEL-002 and its picker show the same localized time zone name as TEL-053 (UX-002).
struct TimeZoneDisplayTests {
    @Test("SPEC-002/UX-002 TEL-002 shows the localized name for the default time zone")
    func defaultTimeZoneUsesLocalizedName() {
        #expect(TimeZoneDisplay.displayName(for: "America/Sao_Paulo") == "Horário de Brasília")
    }

    @Test("SPEC-002/UX-002 curated time zones resolve to their curated names", arguments: TimeZoneDisplay.standardOptions)
    func curatedTimeZonesUseCuratedNames(option: FamilyTimeZoneOption) {
        #expect(TimeZoneDisplay.displayName(for: option.identifier) == option.name)
    }

    @Test("SPEC-002/UX-002 time zones outside the curated list fall back to the city name")
    func uncuratedTimeZoneFallsBackToCity() {
        #expect(TimeZoneDisplay.displayName(for: "Asia/Tokyo") == "Tokyo")
        #expect(TimeZoneDisplay.displayName(for: "America/New_York") == "New York")
    }
}
