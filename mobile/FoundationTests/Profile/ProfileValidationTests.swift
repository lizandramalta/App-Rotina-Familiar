import Foundation
@testable import FamilyRoutine
import Testing

struct ProfileValidationTests {
    @Test("SPEC-006 CA-13 accepts a trimmed name of 1 to 60 visible characters")
    func nameBounds() {
        #expect(ProfileValidation.validatedName("  Maria Silva  ") == .success("Maria Silva"))
        #expect(ProfileValidation.validatedName("a") == .success("a"))
        #expect(ProfileValidation.validatedName(String(repeating: "a", count: 60)) == .success(String(repeating: "a", count: 60)))
    }

    @Test("SPEC-006 CA-13 rejects empty, over-long and control-character names")
    func nameRejections() {
        #expect(ProfileValidation.validatedName("") == .failure(.required))
        #expect(ProfileValidation.validatedName("   ") == .failure(.required))
        #expect(ProfileValidation.validatedName(String(repeating: "a", count: 61)) == .failure(.invalidLength))
        #expect(ProfileValidation.validatedName("Maria\u{0007}") == .failure(.invalidContent))
        #expect(ProfileValidation.validatedName("Maria\n") == .failure(.invalidContent))
    }

    @Test("SPEC-006 CA-06 accepts composite emoji, which count as one visible character")
    func compositeEmoji() {
        #expect(ProfileValidation.validatedName("👨‍👩‍👧‍👦") == .success("👨‍👩‍👧‍👦"))
        #expect(ProfileValidation.validatedNickname(String(repeating: "👨‍👩‍👧‍👦", count: 20)) == .success(String(repeating: "👨‍👩‍👧‍👦", count: 20)))
    }

    @Test("SPEC-006 CA-06 nickname is optional: blank after trim removes it")
    func nicknameOptional() {
        #expect(ProfileValidation.validatedNickname("") == .success(nil))
        #expect(ProfileValidation.validatedNickname("   ") == .success(nil))
        #expect(ProfileValidation.validatedNickname("  Mari  ") == .success("Mari"))
    }

    @Test("SPEC-006 CA-06 internal spaces do not count toward the 20 non-space limit")
    func nicknameInternalSpaces() {
        let twentyWithSpace = String(repeating: "a", count: 10) + " " + String(repeating: "b", count: 10)
        #expect(ProfileValidation.validatedNickname(twentyWithSpace) == .success(twentyWithSpace))
        #expect(ProfileValidation.nonWhitespaceCount(twentyWithSpace) == 20)
    }

    @Test("SPEC-006 CA-06 rejects 21 non-space characters and control characters")
    func nicknameRejections() {
        #expect(ProfileValidation.validatedNickname(String(repeating: "a", count: 21)) == .failure(.invalidLength))
        #expect(ProfileValidation.validatedNickname("Mari\u{0007}") == .failure(.invalidContent))
    }

    @Test("nonWhitespaceCount ignores the ends and any whitespace")
    func counter() {
        #expect(ProfileValidation.nonWhitespaceCount("  vó  Ana ") == 5)
        #expect(ProfileValidation.nonWhitespaceCount("   ") == 0)
    }

    @Test("SPEC-006 CA-10 with no participations all four milestones are pending and bronze is the target")
    func displayItemsEmpty() {
        let overview = BadgesOverview(
            totalParticipations: 0,
            nextTier: NextBadgeTier(code: .bronze, requiredMissionCount: 5, remaining: 5),
            awards: []
        )

        let items = overview.displayItems()

        #expect(items.map(\.tier) == [.bronze, .silver, .gold, .diamond])
        #expect(items.map(\.requiredMissionCount) == [5, 10, 25, 50])
        #expect(items.allSatisfy { !$0.isConquered && $0.awardID == nil && $0.awardedAt == nil })
        #expect(items.map(\.isNextTarget) == [true, false, false, false])
    }

    @Test("SPEC-006 CA-01 with bronze conquered, bronze is conquered and silver is the target")
    func displayItemsPartial() {
        let awardID = UUID()
        let awardedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let overview = BadgesOverview(
            totalParticipations: 7,
            nextTier: NextBadgeTier(code: .silver, requiredMissionCount: 10, remaining: 3),
            awards: [BadgeAward(awardID: awardID, tier: .bronze, requiredMissionCount: 5, awardedAt: awardedAt)]
        )

        let items = overview.displayItems()

        #expect(items[0].isConquered)
        #expect(items[0].awardID == awardID)
        #expect(items[0].awardedAt == awardedAt)
        #expect(!items[0].isNextTarget)
        #expect(items[1].isNextTarget)
        #expect(!items[1].isConquered)
        #expect(items.dropFirst().allSatisfy { !$0.isConquered })
    }

    @Test("SPEC-006 CA-01 at 50 participations every milestone is conquered and none is a target")
    func displayItemsComplete() {
        let awards = BadgeTier.allCases.map {
            BadgeAward(awardID: UUID(), tier: $0, requiredMissionCount: $0.requiredMissionCount, awardedAt: .now)
        }
        let overview = BadgesOverview(totalParticipations: 50, nextTier: nil, awards: awards)

        let items = overview.displayItems()

        #expect(items.allSatisfy { $0.isConquered && !$0.isNextTarget })
    }

    @Test("BadgeTier orders by required mission count")
    func tierOrdering() {
        #expect(BadgeTier.bronze < .silver)
        #expect(BadgeTier.allCases.sorted() == [.bronze, .silver, .gold, .diamond])
        #expect(BadgeTier.allCases.map(\.requiredMissionCount) == [5, 10, 25, 50])
    }
}
