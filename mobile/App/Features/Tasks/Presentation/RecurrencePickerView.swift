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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    sectionHeader("routines.recurrence.start_section")
                    HStack {
                        Text("routines.recurrence.start_date")
                            .font(.app(.body))
                            .foregroundStyle(Color.App.Text.primary)
                        Spacer()
                        DatePicker("routines.recurrence.start_date", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color.App.Action.primary)
                            .background(Color.App.Background.cardHighlight, in: RoundedRectangle(cornerRadius: AppSpacing.sm))
                            .accessibilityIdentifier("routines.recurrence.start_date")
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.vertical, Self.rowVerticalPadding)
                    .appCard()

                    sectionHeader("routines.recurrence.frequency_section")
                    VStack(spacing: 0) {
                        option(nil, label: String(localized: "routines.recurrence.none"))
                        ForEach(RoutineFrequency.allCases, id: \.rawValue) { value in
                            Rectangle()
                                .fill(Color.App.Border.separator)
                                .frame(height: 1)
                                .padding(.leading, AppSpacing.xxl)
                            option(value, label: label(for: value))
                        }
                    }
                    .appCard()

                    Text("routines.recurrence.no_end_date_hint")
                        .font(.app(.caption))
                        .foregroundStyle(Color.App.Text.secondary)
                        .padding(.horizontal, AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.lg)
                // Prototype spacing: content starts 8 pt below the bar.
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .background(Color.App.Background.app.ignoresSafeArea())
            // Content that fits stays still instead of bouncing under the bar (larger text still scrolls).
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("routines.recurrence.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.App.Text.primary)
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
                    .tint(Color.App.Action.primary)
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
        .frame(maxWidth: Self.maxSheetWidth)
    }

    private static let minRowHeight: CGFloat = 44
    private static let rowVerticalPadding: CGFloat = 15
    private static let maxSheetWidth: CGFloat = 540

    private func option(_ value: RoutineFrequency?, label: String) -> some View {
        Button {
            frequency = value
        } label: {
            HStack {
                Text(label)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer()
                if frequency == value {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.base)
            .frame(minHeight: Self.minRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(frequency == value ? Text("routines.recurrence.selected") : Text(""))
        .accessibilityIdentifier("routines.recurrence.option.\(value?.rawValue ?? 0)")
    }

    /// Small secondary section title above a card, as in the prototype.
    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.app(.caption))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.leading, AppSpacing.xxl)
    }

    private func label(for value: RoutineFrequency) -> String {
        if value == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), value.rawValue)
    }
}
