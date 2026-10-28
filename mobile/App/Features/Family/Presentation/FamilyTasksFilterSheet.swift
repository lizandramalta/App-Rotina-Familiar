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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("family.settings.hub.cancel")
                Spacer()
                Button("family.period.clear") { clear() }
                    .font(.subheadline)
                    .foregroundStyle(isDefault ? Color(uiColor: .tertiaryLabel) : .primary)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(isDefault)
                    .frame(minWidth: 54, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.tasks.filter.clear")
            }
            .overlay { Text("family.period.filter_title").font(.headline).allowsHitTesting(false) }
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("family.period.section")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            DatePicker("family.period.start", selection: $start,
                                       in: firstDate ... lastDate, displayedComponents: .date)
                                .accessibilityIdentifier("family.period.start")
                            Divider()
                            DatePicker("family.period.end", selection: $end,
                                       in: start ... lastDate, displayedComponents: .date)
                                .accessibilityIdentifier("family.period.end")
                        }
                        .datePickerStyle(.compact)
                        .padding(.horizontal, 16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 18))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("family.tasks.filter.status")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            statusChip(.all)
                            statusChip(.pending)
                        }
                        HStack(spacing: 8) {
                            if statuses.contains(.awaitingConfirmation) {
                                statusChip(.awaitingConfirmation)
                            }
                            statusChip(.completed)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                onApply(selectedRange, status)
                dismiss()
            } label: {
                Text(applyTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(start > end)
            .accessibilityIdentifier("family.period.apply")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
        .presentationDetents([.height(518), .large])
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

    private func statusChip(_ value: FamilyTaskStatusFilter) -> some View {
        Button {
            status = value
        } label: {
            Text(title(value))
                .font(.subheadline.weight(status == value ? .semibold : .regular))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(status == value ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white,
                            in: Capsule())
                .overlay(Capsule().strokeBorder(status == value ? .clear : Color(uiColor: .separator), lineWidth: 0.5))
                .foregroundStyle(status == value ? Color.white : Color.primary)
                .fixedSize(horizontal: true, vertical: false)
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
        let calendar = Self.calendar(for: timeZoneID)
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? today
        return (max(monday, firstDate), min(sunday, lastDate))
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
