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
                Section {
                    DatePicker("routines.recurrence.start_date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("routines.recurrence.start_date")
                } header: {
                    sectionHeader("routines.recurrence.start_section")
                }

                Section {
                    option(nil, label: String(localized: "routines.recurrence.none"))
                    ForEach(RoutineFrequency.allCases, id: \.rawValue) { value in
                        option(value, label: label(for: value))
                    }
                } header: {
                    sectionHeader("routines.recurrence.frequency_section")
                } footer: {
                    Text("routines.recurrence.no_end_date_hint")
                        .font(.footnote)
                }
            }
            // Prototype spacing: content starts 8 pt below the bar and sections sit close together.
            .listSectionSpacing(.compact)
            .contentMargins(.top, 8, for: .scrollContent)
            // Content that fits stays still instead of bouncing under the bar (larger text still scrolls).
            .scrollBounceBehavior(.basedOnSize)
            .environment(\.defaultMinListRowHeight, 50)
            .navigationTitle("routines.recurrence.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("routines.recurrence.cancel")
                    .accessibilityIdentifier("routines.recurrence.cancel")
                }
                // `.confirmationAction` renders the prominent filled ✓ circle of the prototype.
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onConfirm(startDate, frequency)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel("routines.recurrence.confirm")
                    .accessibilityIdentifier("routines.recurrence.confirm")
                }
            }
        }
        // One size, as in the prototype: a second (large) detent made a scroll resize the sheet
        // into a different-looking full-height card. Scrolling now only moves the content.
        .presentationDetents([.fraction(0.82)])
        .presentationContentInteraction(.scrolls)
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
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .accessibilityLabel(Text(label))
        .accessibilityValue(frequency == value ? Text("routines.recurrence.selected") : Text(""))
        .accessibilityIdentifier("routines.recurrence.option.\(value?.rawValue ?? 0)")
    }

    /// Small secondary section title, as in the prototype, instead of the large default header.
    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        // An explicit label color: `.secondary` inside a Form header is dimmed twice.
        Text(key)
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
    }

    private func label(for value: RoutineFrequency) -> String {
        if value == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), value.rawValue)
    }
}
