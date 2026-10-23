import SwiftUI

/// MOD-002 — recurrence selection is a draft until TEL-013 is saved (UX-008 §5.2).
struct RecurrencePickerView: View {
    @State private var startDate: Date
    @State private var frequency: RoutineFrequency?
    let onConfirm: (Date, RoutineFrequency?) -> Void

    @Environment(\.dismiss) private var dismiss

    init(startDate: Date, frequency: RoutineFrequency?, onConfirm: @escaping (Date, RoutineFrequency?) -> Void) {
        _startDate = State(initialValue: startDate)
        _frequency = State(initialValue: frequency)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("routines.recurrence.start_section") {
                    DatePicker("routines.recurrence.start_date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("routines.recurrence.start_date")
                }

                Section {
                    option(nil, label: String(localized: "routines.recurrence.none"))
                    ForEach(RoutineFrequency.allCases, id: \.rawValue) { value in
                        option(value, label: label(for: value))
                    }
                } header: {
                    Text("routines.recurrence.frequency_section")
                } footer: {
                    Text("routines.recurrence.no_end_date_hint")
                }
            }
            .navigationTitle("routines.recurrence.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("routines.recurrence.cancel") { dismiss() }
                        .accessibilityIdentifier("routines.recurrence.cancel")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onConfirm(startDate, frequency)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("routines.recurrence.confirm")
                    .accessibilityIdentifier("routines.recurrence.confirm")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .frame(maxWidth: 540)
    }

    private func option(_ value: RoutineFrequency?, label: String) -> some View {
        Button {
            frequency = value
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if frequency == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(frequency == value ? Text("routines.recurrence.selected") : Text(""))
        .accessibilityIdentifier("routines.recurrence.option.\(value?.rawValue ?? 0)")
    }

    private func label(for value: RoutineFrequency) -> String {
        if value == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), value.rawValue)
    }
}
