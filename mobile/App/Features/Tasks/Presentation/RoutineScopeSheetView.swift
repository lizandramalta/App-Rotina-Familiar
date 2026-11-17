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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(summary)
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .padding(.horizontal, AppSpacing.xxl)
                        .accessibilityIdentifier("routines.scope.summary")

                    VStack(spacing: 0) {
                        option(.onlyThis, title: "routines.scope.only_this", hint: "routines.scope.only_this_hint")
                        Rectangle()
                            .fill(Color.App.Border.separator)
                            .frame(height: 1)
                            .padding(.leading, AppSpacing.xxl)
                        option(
                            .thisAndFuture,
                            title: "routines.scope.selected_and_future",
                            hint: "routines.scope.selected_and_future_hint"
                        )
                    }
                    .appCard()

                    Text(purpose == .delete ? "routines.scope.delete_hint" : "routines.scope.cancel_hint")
                        .font(.app(.caption))
                        .foregroundStyle(Color.App.Text.secondary)
                        .padding(.horizontal, AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .background(Color.App.Background.app.ignoresSafeArea())
            // Content that fits stays still instead of bouncing under the bar.
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(purpose == .delete ? "routines.scope.delete_title" : "routines.scope.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The prototype shows the whole question between ✕ and ✓, in regular body weight.
                ToolbarItem(placement: .principal) {
                    Text(purpose == .delete ? "routines.scope.delete_title" : "routines.scope.title")
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.App.Text.primary)
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
                    .tint(selection == nil ? Color.App.Border.cardHighlight : Color.App.Action.primary)
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
        .frame(maxWidth: Self.maxSheetWidth)
    }

    private static let maxSheetWidth: CGFloat = 540

    private func option(_ scope: RoutineScope, title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Button {
            selection = scope
        } label: {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                    Text(hint)
                        .font(.app(.caption))
                        .foregroundStyle(Color.App.Text.secondary)
                }
                Spacer()
                if selection == scope {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == scope ? [.isSelected] : [])
        .accessibilityIdentifier(scope == .onlyThis ? "routines.scope.only_this" : "routines.scope.selected_and_future")
    }
}
