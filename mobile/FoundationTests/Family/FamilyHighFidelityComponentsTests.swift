import Foundation
@testable import FamilyRoutine
import Testing

/// SCRUM-126 Phase 1 — TEL-050 high-fidelity helpers (SPEC-009 CA-05/CA-12, UX-009 §2).
@MainActor
struct FamilyHighFidelityComponentsTests {
    private func progress(completed: Int, awaiting: Int, pending: Int) -> FamilyProgress {
        FamilyProgress(
            total: completed + awaiting + pending,
            completed: completed,
            pending: pending,
            awaitingConfirmation: awaiting,
            percentage: nil
        )
    }

    @Test("SPEC-009 CA-12 Admin ring splits completed, awaiting and pending proportionally")
    func adminSegmentsAreProportional() {
        let segments = SegmentedProgressRingView.segments(
            for: progress(completed: 2, awaiting: 1, pending: 1), showsAwaiting: true
        )
        #expect(segments.map(\.kind) == [.completed, .awaiting, .pending])
        #expect(segments.map(\.end) == [0.5, 0.75, 1.0])
        #expect(segments.first?.start == 0)
    }

    @Test("SPEC-009 CA-12 Member ring never draws an awaiting arc")
    func memberSegmentsHideAwaiting() {
        let segments = SegmentedProgressRingView.segments(
            for: progress(completed: 1, awaiting: 2, pending: 1), showsAwaiting: false
        )
        #expect(segments.map(\.kind) == [.completed, .pending])
        #expect(segments.last?.end == 1.0)
    }

    @Test("UX-009 §3 a period without tasks keeps only the neutral track")
    func emptyProgressHasNoSegments() {
        #expect(SegmentedProgressRingView.segments(
            for: progress(completed: 0, awaiting: 0, pending: 0), showsAwaiting: true
        ).isEmpty)
    }

    @Test("TEL-050 member colors are stable and the signed-in member uses Você")
    func paletteIsDeterministic() throws {
        let id = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(FamilyMemberPalette.index(for: id) == FamilyMemberPalette.index(for: id))
        #expect(FamilyMemberPalette.colors(for: id, isCurrentMember: true) == FamilyMemberPalette.you)
        #expect(FamilyMemberPalette.others.contains(FamilyMemberPalette.colors(for: id, isCurrentMember: false)))
    }

    @Test("UX-009 TEL-050 shows Hoje only when today belongs to the range")
    func todayIsShownOnlyInsideRange() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-08T15:00:00Z"))
        let zone = "America/Sao_Paulo"
        #expect(FamilyOverviewDates.containsToday(
            FamilyDateRange(startDate: "2026-10-05", endDate: "2026-10-11"), timeZoneID: zone, now: now
        ))
        #expect(!FamilyOverviewDates.containsToday(
            FamilyDateRange(startDate: "2026-09-28", endDate: "2026-10-04"), timeZoneID: zone, now: now
        ))
    }

    // MARK: SCRUM-126 Phase 5 — chalk rings (Figma 879:13356)

    @Test("Chalk ring passes cover the whole band width, inside the frame")
    func chalkPassesCoverBand() throws {
        let radii = ChalkRing.passRadii(radius: 30, lineWidth: 12)
        #expect(radii.count == 7)
        let first = try #require(radii.first), last = try #require(radii.last)
        #expect(first > 24 && first < 25)
        #expect(last < 36 && last > 35)
        #expect(radii == radii.sorted())
    }

    @Test("A chalk dot never produces a negative or zero radius")
    func chalkDotRadiiArePositive() {
        let radii = ChalkRing.passRadii(radius: 4, lineWidth: 8)
        #expect(!radii.isEmpty)
        #expect(radii.allSatisfy { $0 >= 0.5 })
    }

    @Test("Chalk arcs start at 12 o'clock and an empty segment draws nothing")
    func chalkArcGeometry() {
        let center = CGPoint(x: 35, y: 35)
        #expect(ChalkRing.arc(center: center, radius: 30, from: 0.5, to: 0.5).isEmpty)
        let quarter = ChalkRing.arc(center: center, radius: 30, from: 0, to: 0.25)
        let start = ChalkScatter.segments(of: quarter).first?.0
        #expect(abs((start?.x ?? 0) - 35) < 0.01)
        #expect(abs((start?.y ?? 0) - 5) < 0.01)
        let end = ChalkScatter.segments(of: quarter).last?.1
        #expect(abs((end?.x ?? 0) - 65) < 0.01, "a quarter turn ends at 3 o'clock (clockwise)")
    }


    // MARK: SCRUM-126 Phase 7 — daily default (RN60/RN61, SPEC-009 E-13)

    private func civil(_ value: String, _ zone: String = "America/Sao_Paulo") throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = "yyyy-MM-dd"
        return try #require(formatter.date(from: value))
    }

    @Test("RN60/RN61 the default range is today in the family time zone")
    func defaultRangeIsToday() throws {
        // 01:30 UTC on the 17th is still the 16th in São Paulo.
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-17T01:30:00Z"))
        let range = FamilyRangeFilterSheet.defaultRange(
            firstDate: try civil("2026-11-01"), lastDate: try civil("2026-11-30"),
            timeZoneID: "America/Sao_Paulo", now: now
        )
        #expect(range.start == (try civil("2026-11-16")))
        #expect(range.end == range.start)
    }

    @Test("RN49 the daily default is clamped to the family's first day")
    func defaultRangeClampsToFirstDate() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-16T15:00:00Z"))
        let first = try civil("2026-11-20")
        let range = FamilyRangeFilterSheet.defaultRange(
            firstDate: first, lastDate: try civil("2026-11-30"), timeZoneID: "America/Sao_Paulo", now: now
        )
        #expect(range.start == first && range.end == first)
    }

    @Test("RN60/RN61 only today is the default; a week or another day shows the filter as active")
    func customRangeDetection() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-16T15:00:00Z"))
        let zone = "America/Sao_Paulo"
        #expect(!FamilyRangeFilterSheet.isCustomRange(
            FamilyDateRange(startDate: "2026-11-16", endDate: "2026-11-16"), familyCreatedAt: "2026-11-01", timeZoneID: zone, now: now
        ))
        #expect(FamilyRangeFilterSheet.isCustomRange(
            FamilyDateRange(startDate: "2026-11-16", endDate: "2026-11-22"), familyCreatedAt: "2026-11-01", timeZoneID: zone, now: now
        ))
        #expect(FamilyRangeFilterSheet.isCustomRange(
            FamilyDateRange(startDate: "2026-11-15", endDate: "2026-11-15"), familyCreatedAt: "2026-11-01", timeZoneID: zone, now: now
        ))
    }


    // MARK: SCRUM-126 Phase 8 — daily subtitle and thin ring

    @Test("UX-009 dayCount is inclusive and 1 for a single day")
    func dayCountIsInclusive() {
        let zone = "America/Sao_Paulo"
        #expect(FamilyOverviewDates.dayCount(in: FamilyDateRange(startDate: "2026-11-17", endDate: "2026-11-17"), timeZoneID: zone) == 1)
        #expect(FamilyOverviewDates.dayCount(in: FamilyDateRange(startDate: "2026-11-16", endDate: "2026-11-22"), timeZoneID: zone) == 7)
        #expect(FamilyOverviewDates.dayCount(in: FamilyDateRange(startDate: "x", endDate: "y"), timeZoneID: zone) == 1)
    }

    @Test("UX-009 a single day shows only the weekday after Hoje; two or more days add the date")
    func todaySubtitleDependsOnRangeLength() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-17T15:00:00Z"))
        let zone = "America/Sao_Paulo"
        let daily = FamilyOverviewDates.todaySubtitle(
            for: FamilyDateRange(startDate: "2026-11-17", endDate: "2026-11-17"), timeZoneID: zone, now: now
        )
        let weekly = FamilyOverviewDates.todaySubtitle(
            for: FamilyDateRange(startDate: "2026-11-16", endDate: "2026-11-22"), timeZoneID: zone, now: now
        )
        #expect(!daily.contains("17"), "the day and month are already in the title: \(daily)")
        #expect(weekly.contains("17"), "a range repeats today's date: \(weekly)")
        #expect(weekly.count > daily.count)
    }

    @Test("Figma 918:8277 the family donut uses a thin 7.5 pt chalk band")
    func donutIsThin() {
        let progress = FamilyProgress(total: 1, completed: 1, pending: 0, awaitingConfirmation: 0, percentage: 100)
        #expect(SegmentedProgressRingView(progress: progress, showsAwaiting: true).lineWidth == 7.5)
    }


    // MARK: SCRUM-126 Phase 10 — wrapping status chips (Figma 870:23478)

    @Test("Status chips wrap to a new line when the row is full, keeping order")
    func flowLayoutWraps() {
        let chip = CGSize(width: 100, height: 40)
        let rows = FamilyFlowLayout.rows(sizes: [chip, chip, chip, chip], maxWidth: 320, spacing: 8)
        #expect(rows.map(\.indices) == [[0, 1, 2], [3]])
        #expect(rows.first?.width == 316)
        #expect(rows.allSatisfy { $0.height == 40 })
    }

    @Test("A chip wider than the row still gets its own line")
    func flowLayoutOversizedChip() {
        let rows = FamilyFlowLayout.rows(
            sizes: [CGSize(width: 400, height: 40), CGSize(width: 50, height: 40)], maxWidth: 320, spacing: 8
        )
        #expect(rows.map(\.indices) == [[0], [1]])
    }

}
