import SwiftUI

/// Shared inclusive Início/Fim picker for the approved Family screens (RN61).
struct FamilyRangeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var previewCount: Int?

    let firstDate: Date
    let lastDate: Date
    let timeZoneID: String
    let taskCount: Int?
    let originalRange: FamilyDateRange
    let countProvider: (FamilyDateRange) async throws -> Int
    let onApply: (FamilyDateRange) -> Void

    init(
        range: FamilyDateRange,
        firstDate: String,
        timeZoneID: String,
        taskCount: Int? = nil,
        countProvider: @escaping (FamilyDateRange) async throws -> Int,
        onApply: @escaping (FamilyDateRange) -> Void
    ) {
        let calendar = Self.calendar(for: timeZoneID)
        let first = Self.date(from: firstDate, calendar: calendar) ?? .now
        let startDate = Self.date(from: range.startDate, calendar: calendar) ?? first
        let endDate = Self.date(from: range.endDate, calendar: calendar) ?? startDate
        _start = State(initialValue: startDate)
        _end = State(initialValue: endDate)
        self.firstDate = first
        let lastDay = calendar.dateInterval(of: .month, for: .now)?.end.addingTimeInterval(-1) ?? .now
        self.lastDate = calendar.startOfDay(for: lastDay)
        self.timeZoneID = timeZoneID
        self.taskCount = taskCount
        self.originalRange = range
        self.countProvider = countProvider
        self.onApply = onApply
    }

    private enum Field { case start, end }
    @State private var expandedField: Field?
    @State private var detent: PresentationDetent = Self.compactDetent
    private static let compactDetent = PresentationDetent.height(372)

    var body: some View {
        VStack(spacing: 0) {
            FamilyFilterSheetTopBar(
                clearIdentifier: "family.overview.filter.clear",
                isDefault: isDefault,
                onClear: clear,
                onClose: { dismiss() }
            )
            .padding(.bottom, AppSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("family.period.section")
                        .font(.app(.subtitleStrong))
                        .foregroundStyle(Color.App.Text.secondary)
                        .padding(.leading, AppSpacing.xs)

                    VStack(spacing: 0) {
                        FamilyDateCapsuleRow(
                            title: "family.period.start", identifier: "family.period.start",
                            selection: $start, bounds: firstDate ... lastDate,
                            isExpanded: expandedField == .start, onToggle: { toggle(.start) }
                        )
                        Rectangle()
                            .fill(Color.App.Border.separator)
                            .frame(height: 1)
                        FamilyDateCapsuleRow(
                            title: "family.period.end", identifier: "family.period.end",
                            selection: $end, bounds: start ... lastDate,
                            isExpanded: expandedField == .end, onToggle: { toggle(.end) }
                        )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .appCard(cornerRadius: AppRadius.cardBoard)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Button {
                let calendar = Self.calendar(for: timeZoneID)
                onApply(FamilyDateRange(
                    startDate: Self.string(from: start, calendar: calendar),
                    endDate: Self.string(from: end, calendar: calendar)
                ))
                dismiss()
            } label: {
                Text(applyTitle)
            }
            .buttonStyle(AppPillButtonStyle(kind: .primary))
            .disabled(start > end)
            .padding(.top, AppSpacing.md)
            .accessibilityIdentifier("family.period.apply")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.lg)
        .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
        .background(Color.App.Background.app.ignoresSafeArea())
        .presentationDetents([Self.compactDetent, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: start) { _, newValue in
            if end < newValue { end = newValue }
        }
        .task(id: previewKey) {
            previewCount = nil
            do {
                let count = try await countProvider(selectedRange)
                if !Task.isCancelled { previewCount = count }
            } catch {
                previewCount = nil
            }
        }
    }

    private func toggle(_ field: Field) {
        withAnimation(.snappy) {
            expandedField = expandedField == field ? nil : field
            // The inline calendar does not fit the compact detent.
            if expandedField != nil { detent = .large }
        }
    }

    private var applyTitle: String {
        let count = previewCount ?? (selectedRange == originalRange ? taskCount : nil)
        if count == 1 { return String(localized: "family.period.show_one_task") }
        if let count { return String(format: String(localized: "family.period.show_tasks_count"), count) }
        return String(localized: "family.period.show_tasks")
    }

    private var selectedRange: FamilyDateRange {
        let calendar = Self.calendar(for: timeZoneID)
        return FamilyDateRange(
            startDate: Self.string(from: start, calendar: calendar),
            endDate: Self.string(from: end, calendar: calendar)
        )
    }

    private var previewKey: String { "\(selectedRange.startDate)|\(selectedRange.endDate)" }

    private var defaultRange: (start: Date, end: Date) {
        Self.defaultRange(firstDate: firstDate, lastDate: lastDate, timeZoneID: timeZoneID)
    }

    /// Today in the family time zone, clamped to RN49 bounds: the initial selection and what "Limpar" restores
    /// (RN60/RN61, SPEC-009 E-13).
    static func defaultRange(
        firstDate: Date, lastDate: Date, timeZoneID: String, now: Date = .now
    ) -> (start: Date, end: Date) {
        let today = calendar(for: timeZoneID).startOfDay(for: now)
        let clamped = min(max(today, firstDate), lastDate)
        return (clamped, clamped)
    }

    /// Whether `range` differs from the default day, so the header filter shows as active.
    static func isCustomRange(
        _ range: FamilyDateRange, familyCreatedAt: String, timeZoneID: String, now: Date = .now
    ) -> Bool {
        let calendar = calendar(for: timeZoneID)
        let first = date(from: familyCreatedAt, calendar: calendar) ?? now
        let lastDay = calendar.dateInterval(of: .month, for: now)?.end.addingTimeInterval(-1) ?? now
        let value = defaultRange(
            firstDate: first, lastDate: calendar.startOfDay(for: lastDay), timeZoneID: timeZoneID, now: now
        )
        return range.startDate != string(from: value.start, calendar: calendar)
            || range.endDate != string(from: value.end, calendar: calendar)
    }

    private var isDefault: Bool {
        let value = defaultRange
        return start == value.start && end == value.end
    }

    private func clear() {
        let value = defaultRange
        start = value.start
        end = value.end
    }

    private static func calendar(for timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    private static func date(from string: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private static func string(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
