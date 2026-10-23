import SwiftUI

/// MOD-012 — Confirmar aplicação do fuso.
/// Apresenta o resumo de prévia (De/Para), impacto de transição, seleção de aplicação
/// (Aplicar agora / Aplicar no próximo ciclo), bloqueio durante confirmação e tratamento de erros.
struct FamilyTimeZoneConfirmationSheetView: View {
    @ObservedObject var viewModel: FamilySettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if let preview = viewModel.preview {
                    Section {
                        LabeledContent {
                            Text(currentFusoText)
                                .foregroundStyle(.secondary)
                        } label: {
                            Text("family.time_zone.preview_from")
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent {
                            Text(proposedFusoText(preview.proposedTimeZoneID))
                                .foregroundStyle(.primary)
                        } label: {
                            Text("family.time_zone.preview_to")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("family.time_zone.preview_section")
                    } footer: {
                        if preview.isTransition || viewModel.selectedApplication == .immediate {
                            Text("family.time_zone.transition_warning")
                        } else {
                            Text("family.time_zone.history_preserved")
                        }
                    }

                    Section {
                        applicationRow(
                            titleKey: "family.time_zone.apply_now",
                            subtitleKey: "family.time_zone.apply_now_subtitle",
                            mode: .immediate
                        )

                        applicationRow(
                            titleKey: "family.time_zone.apply_next_cycle",
                            subtitleKey: "family.time_zone.apply_next_cycle_subtitle",
                            mode: .nextCycle
                        )
                    } header: {
                        Text("family.time_zone.when_to_apply")
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("family.time_zone.modal_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.cancelConfirmation()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityLabel("family.time_zone.cancel_button")
                    .accessibilityIdentifier("family.time_zone.cancel_button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.confirmChange()
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .frame(minWidth: 44, minHeight: 44)
                        } else {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .disabled(viewModel.isSubmitting || viewModel.preview == nil)
                    .accessibilityLabel("family.time_zone.confirm_button")
                    .accessibilityIdentifier("family.time_zone.confirm_button")
                }
            }
            .interactiveDismissDisabled(viewModel.isSubmitting)
        }
    }

    private var currentFusoText: String {
        guard let current = viewModel.currentSettings?.timeZoneID else { return "" }
        return "\(TimeZoneDisplay.displayName(for: current)) (\(current))"
    }

    private func proposedFusoText(_ id: String) -> String {
        "\(TimeZoneDisplay.displayName(for: id)) (\(id))"
    }

    @ViewBuilder
    private func applicationRow(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey,
        mode: TimeZoneApplication
    ) -> some View {
        Button {
            Task {
                await viewModel.updateApplicationMode(mode)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .foregroundStyle(.primary)
                        .font(.body)
                    Text(subtitleKey)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                Spacer()
                if viewModel.selectedApplication == mode {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
        .accessibilityIdentifier("family.time_zone.mode.\(mode.rawValue)")
    }
}
