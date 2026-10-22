import SwiftUI

/// MOD-014 — required on every saved edit of an `awaitingConfirmation` task, even when only the
/// note changed (RN66/CA-12/13/14). No signaler name/time: SPEC-013, the only endpoint that could
/// supply it, isn't implemented yet and is Administrator-only; UX-007's own approved copy (§7)
/// doesn't call for that line either.
struct SignalResolutionView: View {
    @Bindable var viewModel: TaskEditorViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("tasks.signal_resolution.title")
                    .font(.headline)

                VStack(spacing: 0) {
                    option(
                        .resetToPending,
                        title: "tasks.signal_resolution.option_reset",
                        hint: "tasks.signal_resolution.option_reset_hint"
                    )
                    Divider().padding(.leading, 20)
                    option(
                        .keepAwaitingConfirmation,
                        title: "tasks.signal_resolution.option_keep",
                        hint: "tasks.signal_resolution.option_keep_hint"
                    )
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 26))

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { viewModel.cancelSignalResolution() }
                        .disabled(viewModel.isSaving)
                        .accessibilityIdentifier("tasks.signal_resolution.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Confirmar") { Task { await viewModel.confirmSignalResolutionAndSave() } }
                            .disabled(viewModel.signalResolutionChoice == nil)
                            .accessibilityIdentifier("tasks.signal_resolution.confirm")
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func option(_ value: SignalResolution, title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Button {
            viewModel.chooseSignalResolution(value)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.signalResolutionChoice == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(20)
        }
        .accessibilityIdentifier("tasks.signal_resolution.option.\(value.rawValue)")
    }
}
