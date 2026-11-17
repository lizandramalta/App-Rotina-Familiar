import SwiftUI

/// MOD-014 — required on every saved edit of an `awaitingConfirmation` task, even when only the
/// note changed (RN66/CA-12/13/14). No signaler name/time: SPEC-013, the only endpoint that could
/// supply it, isn't implemented yet and is Administrator-only; UX-007's own approved copy (§7)
/// doesn't call for that line either.
struct SignalResolutionView: View {
    @Bindable var viewModel: TaskEditorViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("tasks.signal_resolution.title")
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .padding(.horizontal, AppSpacing.xxl)

                    VStack(spacing: 0) {
                        option(
                            .resetToPending,
                            title: "tasks.signal_resolution.option_reset",
                            hint: "tasks.signal_resolution.option_reset_hint"
                        )
                        Rectangle()
                            .fill(Color.App.Border.separator)
                            .frame(height: 1)
                            .padding(.leading, AppSpacing.xxl)
                        option(
                            .keepAwaitingConfirmation,
                            title: "tasks.signal_resolution.option_keep",
                            hint: "tasks.signal_resolution.option_keep_hint"
                        )
                    }
                    .appCard()

                    if viewModel.isSaving {
                        Text("tasks.form.submitting")
                            .font(.app(.caption))
                            .foregroundStyle(Color.App.Text.secondary)
                            .padding(.horizontal, AppSpacing.xxl)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.App.Background.app.ignoresSafeArea())
            .navigationTitle("tasks.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.cancelSignalResolution()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.App.Text.primary)
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityLabel(Text("Cancelar"))
                    .accessibilityIdentifier("tasks.signal_resolution.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task { await viewModel.confirmSignalResolutionAndSave() }
                        } label: {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.App.Action.primary)
                        .disabled(viewModel.signalResolutionChoice == nil)
                        .accessibilityLabel(Text("Confirmar"))
                        .accessibilityIdentifier("tasks.signal_resolution.confirm")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func option(_ value: SignalResolution, title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Button {
            viewModel.chooseSignalResolution(value)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                    Text(hint)
                        .font(.app(.caption))
                        .foregroundStyle(Color.App.Text.secondary)
                }
                Spacer()
                if viewModel.signalResolutionChoice == value {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(AppSpacing.xxl)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.signalResolutionChoice == value ? .isSelected : [])
        .accessibilityIdentifier("tasks.signal_resolution.option.\(value.rawValue)")
    }
}
