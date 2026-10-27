import SwiftUI

/// Shared inclusive Início/Fim picker for the approved Family screens (RN61).
struct FamilyRangeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date

    let firstDate: Date
    let lastDate: Date
    let timeZoneID: String
    let onApply: (FamilyDateRange) -> Void

    init(
        range: FamilyDateRange,
        firstDate: String,
        timeZoneID: String,
        onApply: @escaping (FamilyDateRange) -> Void
    ) {
        let calendar = Self.calendar(for: timeZoneID)
        let first = Self.date(from: firstDate, calendar: calendar) ?? .now
        let startDate = Self.date(from: range.startDate, calendar: calendar) ?? first
        let endDate = Self.date(from: range.endDate, calendar: calendar) ?? startDate
        _start = State(initialValue: startDate)
        _end = State(initialValue: endDate)
        self.firstDate = first
        self.lastDate = calendar.dateInterval(of: .month, for: .now)?.end.addingTimeInterval(-1) ?? .now
        self.timeZoneID = timeZoneID
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("family.period.start", selection: $start, in: firstDate ... lastDate, displayedComponents: .date)
                    .accessibilityIdentifier("family.period.start")
                DatePicker("family.period.end", selection: $end, in: start ... lastDate, displayedComponents: .date)
                    .accessibilityIdentifier("family.period.end")
            }
            .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
            .navigationTitle("family.period.filter_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("family.settings.hub.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("family.period.apply") {
                        let calendar = Self.calendar(for: timeZoneID)
                        onApply(FamilyDateRange(
                            startDate: Self.string(from: start, calendar: calendar),
                            endDate: Self.string(from: end, calendar: calendar)
                        ))
                        dismiss()
                    }
                    .disabled(start > end)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: start) { _, newValue in
            if end < newValue { end = newValue }
        }
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
