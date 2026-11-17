import SwiftUI

/// TEL-011 filter sheet: inclusive free range and role-specific status in one confirmation.
struct FamilyTasksFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var status: FamilyTaskStatusFilter
    @State private var previewCount: Int?

    let statuses: [FamilyTaskStatusFilter]
    let firstDate: Date
    let lastDate: Date
    let timeZoneID: String
    let countProvider: (FamilyDateRange, FamilyTaskStatusFilter) async throws -> Int?
    let onApply: (FamilyDateRange, FamilyTaskStatusFilter) -> Void

    init(
        range: FamilyDateRange,
        status: FamilyTaskStatusFilter,
        statuses: [FamilyTaskStatusFilter],
        firstDate: String,
        timeZoneID: String,
        countProvider: @escaping (FamilyDateRange, FamilyTaskStatusFilter) async throws -> Int?,
        onApply: @escaping (FamilyDateRange, FamilyTaskStatusFilter) -> Void
    ) {
        let calendar = Self.calendar(for: timeZoneID)
        let first = Self.date(from: firstDate, calendar: calendar) ?? .now
        let initialStart = Self.date(from: range.startDate, calendar: calendar) ?? first
        let initialEnd = Self.date(from: range.endDate, calendar: calendar) ?? initialStart
        _start = State(initialValue: initialStart)
        _end = State(initialValue: initialEnd)
        _status = State(initialValue: status)
        self.statuses = statuses
        self.firstDate = first
        let lastDay = calendar.dateInterval(of: .month, for: .now)?.end.addingTimeInterval(-1) ?? .now
        self.lastDate = calendar.startOfDay(for: lastDay)
        self.timeZoneID = timeZoneID
        self.countProvider = countProvider
        self.onApply = onApply
    }

    private enum Field { case start, end }
    @State private var expandedField: Field?
    @State private var detent: PresentationDetent = Self.compactDetent
    private static let compactDetent = PresentationDetent.height(518)

    var body: some View {
        VStack(spacing: 0) {
            FamilyFilterSheetTopBar(
                clearIdentifier: "family.tasks.filter.clear",
                isDefault: isDefault,
                onClear: clear,
                onClose: { dismiss() }
            )
            .padding(.bottom, AppSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sectionTitle("family.period.section")
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
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        sectionTitle("family.tasks.filter.status")
                        // Wrapping chips: every allowed status stays visible without initial scrolling (UX-009).
                        FamilyFlowLayout(spacing: AppSpacing.sm) {
                            ForEach(statuses, id: \.self) { statusChip($0) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button {
                onApply(selectedRange, status)
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
        .background(Color.App.Background.app.ignoresSafeArea())
        .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
        .presentationDetents([Self.compactDetent, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: start) { _, value in
            if end < value { end = value }
        }
        .task(id: previewKey) {
            previewCount = nil
            do {
                let count = try await countProvider(selectedRange, status)
                if !Task.isCancelled { previewCount = count }
            } catch {
                previewCount = nil
            }
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.leading, AppSpacing.xs)
    }

    private func toggle(_ field: Field) {
        withAnimation(.snappy) {
            expandedField = expandedField == field ? nil : field
            if expandedField != nil { detent = .large }
        }
    }

    private func statusChip(_ value: FamilyTaskStatusFilter) -> some View {
        Button {
            status = value
        } label: {
            Text(title(value))
                .padding(.horizontal, AppSpacing.base)
                .familyChip(isSelected: status == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(status == value ? .isSelected : [])
        .accessibilityIdentifier("family.tasks.status.\(value.rawValue)")
    }

    private func title(_ value: FamilyTaskStatusFilter) -> LocalizedStringKey {
        switch value {
        case .all: "family.tasks.status.all"
        case .pending: "family.tasks.status.pending"
        case .awaitingConfirmation: "family.tasks.status.awaiting"
        case .completed: "family.tasks.status.completed"
        }
    }

    private var selectedRange: FamilyDateRange {
        let calendar = Self.calendar(for: timeZoneID)
        return FamilyDateRange(
            startDate: Self.string(from: start, calendar: calendar),
            endDate: Self.string(from: end, calendar: calendar)
        )
    }

    private var previewKey: String {
        "\(selectedRange.startDate)|\(selectedRange.endDate)|\(status.rawValue)"
    }

    private var applyTitle: String {
        guard let previewCount else { return String(localized: "family.period.show_tasks") }
        if previewCount == 1 { return String(localized: "family.period.show_one_task") }
        return String(format: String(localized: "family.period.show_tasks_count"), previewCount)
    }

    private var defaultRange: (start: Date, end: Date) {
        FamilyRangeFilterSheet.defaultRange(firstDate: firstDate, lastDate: lastDate, timeZoneID: timeZoneID)
    }

    private var isDefault: Bool {
        let value = defaultRange
        return status == .all && start == value.start && end == value.end
    }

    private func clear() {
        let value = defaultRange
        start = value.start
        end = value.end
        status = .all
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
