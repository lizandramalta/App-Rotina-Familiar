import SwiftUI

/// What MOD-003 is choosing the scope for (UX-008 §5.3).
enum RoutineScopePurpose: Equatable {
    case edit
    case delete
}

/// MOD-003 — always offers "Somente esta tarefa" and "Esta tarefa e as futuras" before editing or
/// deleting a routine occurrence (UX-008 UX-04). Confirmar stays disabled until a choice is made.
struct RoutineScopeSheetView: View {
    let purpose: RoutineScopePurpose
    let summary: String
    let onConfirm: (RoutineScope) -> Void

    @State private var selection: RoutineScope?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    option(.onlyThis, title: "routines.scope.only_this", hint: "routines.scope.only_this_hint")
                    option(
                        .thisAndFuture,
                        title: "routines.scope.selected_and_future",
                        hint: "routines.scope.selected_and_future_hint"
                    )
                } header: {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .label))
                        .textCase(nil)
                        .accessibilityIdentifier("routines.scope.summary")
                } footer: {
                    Text(purpose == .delete ? "routines.scope.delete_hint" : "routines.scope.cancel_hint")
                        .font(.footnote)
                }
            }
            .contentMargins(.top, 8, for: .scrollContent)
            // Content that fits stays still instead of bouncing under the bar.
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(purpose == .delete ? "routines.scope.delete_title" : "routines.scope.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The prototype shows the whole question between ✕ and ✓, in regular body weight.
                ToolbarItem(placement: .principal) {
                    Text(purpose == .delete ? "routines.scope.delete_title" : "routines.scope.title")
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Cancelar"))
                    .accessibilityIdentifier("routines.scope.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let selection else { return }
                        dismiss()
                        onConfirm(selection)
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(selection == nil ? Color(uiColor: .systemGray3) : .accentColor)
                    .disabled(selection == nil)
                    .accessibilityLabel(Text("Confirmar"))
                    .accessibilityIdentifier("routines.scope.confirm")
                }
            }
        }
        // One size, as in the prototype: scrolling moves the content, never resizes the sheet.
        .presentationDetents([.medium])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .frame(maxWidth: 540)
    }

    private func option(_ scope: RoutineScope, title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Button {
            selection = scope
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selection == scope {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == scope ? [.isSelected] : [])
        .accessibilityIdentifier(scope == .onlyThis ? "routines.scope.only_this" : "routines.scope.selected_and_future")
    }
}
