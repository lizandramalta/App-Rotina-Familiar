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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .frame(minWidth: 54, minHeight: 44)
                    .buttonStyle(.plain)
                    .disabled(isDefault)
                    .accessibilityIdentifier("family.overview.filter.clear")
            }
            .overlay { Text("family.period.filter_title").font(.headline).allowsHitTesting(false) }
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 10) {
                Text("family.period.section")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    DatePicker("family.period.start", selection: $start, in: firstDate ... lastDate, displayedComponents: .date)
                        .accessibilityIdentifier("family.period.start")
                    Divider()
                    DatePicker("family.period.end", selection: $end, in: start ... lastDate, displayedComponents: .date)
                        .accessibilityIdentifier("family.period.end")
                }
                .datePickerStyle(.compact)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            }
            Spacer(minLength: 0)
            Button {
                let calendar = Self.calendar(for: timeZoneID)
                onApply(FamilyDateRange(
                    startDate: Self.string(from: start, calendar: calendar),
                    endDate: Self.string(from: end, calendar: calendar)
                ))
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
        .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.height(372), .large])
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
        let calendar = Self.calendar(for: timeZoneID)
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? today
        return (max(monday, firstDate), min(sunday, lastDate))
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
