import SwiftUI

/// MOD-008 — adicionar item de recompensa (SPEC-015 Fase 1). Sempre sheet sobre TEL-023, mesmo
/// padrão de MOD-007 sobre TEL-022.
struct RewardItemEditorView: View {
    @State private var viewModel: RewardItemEditorViewModel
    let onSaved: (RewardItem) -> Void
    let onUncertain: () -> Void

    @State private var isDiscardConfirmationPresented = false
    @Environment(\.dismiss) private var dismiss

    init(
        repository: any RewardRepository,
        accessToken: String,
        onSaved: @escaping (RewardItem) -> Void,
        onUncertain: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: RewardItemEditorViewModel(repository: repository, accessToken: accessToken))
        self.onSaved = onSaved
        self.onUncertain = onUncertain
    }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("rewards.editor.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            if viewModel.hasTypedContent {
                                isDiscardConfirmationPresented = true
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityIdentifier("rewards.editor.close")
                        .accessibilityLabel(Text("rewards.editor.close"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.isSaving {
                            ProgressView()
                                .accessibilityLabel("rewards.editor.submitting")
                        } else {
                            Button {
                                Task { await viewModel.saveIfValid() }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .disabled(!viewModel.isFormValid)
                            .accessibilityIdentifier("rewards.editor.submit")
                            .accessibilityLabel(Text("rewards.editor.submit"))
                        }
                    }
                }
                .confirmationDialog(
                    "rewards.editor.discard_title",
                    isPresented: $isDiscardConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button("rewards.editor.discard_confirm", role: .destructive) { dismiss() }
                    Button("rewards.editor.discard_cancel", role: .cancel) {}
                } message: {
                    Text("rewards.editor.discard_message")
                }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
        .onChange(of: viewModel.outcome) { _, outcome in
            switch outcome {
            case let .saved(item):
                dismiss()
                onSaved(item)
            case .uncertain:
                dismiss()
                onUncertain()
            case nil:
                break
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("rewards.editor.field.title")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("rewards.editor.title_placeholder", text: $viewModel.title)
                        .accessibilityIdentifier("rewards.editor.title")
                    Text(Self.counterText(key: "rewards.editor.title_counter", count: nonWhitespaceCount(viewModel.title)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let titleError = viewModel.titleError {
                    Text(titleErrorMessage(for: titleError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("rewards.editor.title_error")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("rewards.editor.field.details")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("rewards.editor.details_placeholder", text: $viewModel.details, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityIdentifier("rewards.editor.details")
                    Text(Self.counterText(key: "rewards.editor.details_counter", count: viewModel.details.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if viewModel.detailsError != nil {
                    Text("rewards.editor.error.details_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("rewards.editor.details_error")
                }
            }

            Section {
                Text("rewards.editor.helper")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let banner = viewModel.banner {
                Section {
                    Text(bannerMessage(for: banner))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("rewards.editor.banner")
                }
            }
        }
    }

    private func nonWhitespaceCount(_ text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isWhitespace }.count
    }

    private static func counterText(key: String.LocalizationValue, count: Int) -> String {
        String(format: String(localized: key), count)
    }

    private func titleErrorMessage(for error: RewardFieldError) -> LocalizedStringKey {
        switch error {
        case .required:
            "rewards.editor.error.title_required"
        case .invalid:
            "rewards.editor.error.title_too_long"
        case .duplicate:
            "rewards.editor.error.title_duplicate"
        }
    }

    private func bannerMessage(for banner: RewardItemEditorBanner) -> LocalizedStringKey {
        switch banner {
        case .networkFailure:
            "missions.common.error_network"
        case .duplicateTitle:
            "rewards.editor.error.title_duplicate"
        case .rejected:
            "missions.common.error_unavailable"
        }
    }
}
