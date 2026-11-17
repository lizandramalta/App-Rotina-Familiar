import SwiftUI

/// MOD-012 — Confirmar aplicação do fuso.
/// Apresenta o resumo de prévia (De/Para), impacto de transição, seleção de aplicação
/// (Aplicar agora / Aplicar no próximo ciclo), bloqueio durante confirmação e tratamento de erros.
struct FamilyTimeZoneConfirmationSheetView: View {
    @ObservedObject var viewModel: FamilySettingsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                        if let error = viewModel.errorMessage {
                            InlineFeedbackBanner(message: error)
                        }
                        if let preview = viewModel.preview {
                            summarySection(preview)
                            applicationSection
                        } else {
                            RoundedRectangle(cornerRadius: AppRadius.pill)
                                .fill(Color.App.Background.subtle)
                                .frame(height: 120)
                                .accessibilityLabel("family.settings.loading")
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.vertical, AppSpacing.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .background(Color.App.Background.app.ignoresSafeArea())
            .navigationTitle("family.time_zone.modal_title")
            .navigationBarTitleDisplayMode(.inline)
            // Figma 870:26274: ✕ and ✓ in the top bar, #423C1F (no footer buttons).
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.cancelConfirmation()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color.App.Text.primary)
                    .disabled(viewModel.isSubmitting)
                    .accessibilityLabel("family.time_zone.cancel_button")
                    .accessibilityIdentifier("family.time_zone.cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.confirmChange() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView().tint(Color.App.Text.primary)
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .tint(Color.App.Text.primary)
                    .disabled(viewModel.isSubmitting || viewModel.preview == nil)
                    .accessibilityLabel("family.time_zone.confirm_button")
                    .accessibilityIdentifier("family.time_zone.confirm_button")
                }
            }
            .interactiveDismissDisabled(viewModel.isSubmitting)
        }
    }

    private func summarySection(_ preview: TimeZoneChangePreview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.time_zone.preview_section")
            VStack(spacing: 0) {
                summaryRow(label: "family.time_zone.preview_from", value: currentFusoText, emphasized: false)
                FamilyCardSeparator()
                summaryRow(label: "family.time_zone.preview_to", value: proposedFusoText(preview.proposedTimeZoneID), emphasized: true)
            }
            .appCard(cornerRadius: AppRadius.pill)
            Text(preview.isTransition || viewModel.selectedApplication == .immediate
                 ? "family.time_zone.transition_warning" : "family.time_zone.history_preserved")
                .font(.app(.note))
                .foregroundStyle(Color.App.Text.secondary)
                .padding(.horizontal, AppSpacing.lg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryRow(label: LocalizedStringKey, value: String, emphasized: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Text(label)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.secondary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(.app(emphasized ? .subtitleStrong : .subtitle))
                .foregroundStyle(emphasized ? Color.App.Text.primary : Color.App.Text.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.time_zone.when_to_apply")
            VStack(spacing: 0) {
                applicationRow(
                    titleKey: "family.time_zone.apply_now",
                    subtitleKey: "family.time_zone.apply_now_subtitle",
                    mode: .immediate
                )
                FamilyCardSeparator()
                applicationRow(
                    titleKey: "family.time_zone.apply_next_cycle",
                    subtitleKey: "family.time_zone.apply_next_cycle_subtitle",
                    mode: .nextCycle
                )
            }
            .appCard(cornerRadius: AppRadius.pill)
        }
    }

    private var currentFusoText: String {
        guard let current = viewModel.currentSettings?.timeZoneID else { return "" }
        // Display name only, e.g. "Horário de Brasília" (Figma 870:26288).
        return TimeZoneDisplay.displayName(for: current)
    }

    private func proposedFusoText(_ id: String) -> String {
        TimeZoneDisplay.displayName(for: id)
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
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(titleKey)
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                    Text(subtitleKey)
                        .font(.app(.note))
                        .foregroundStyle(Color.App.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if viewModel.selectedApplication == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
        .accessibilityAddTraits(viewModel.selectedApplication == mode ? .isSelected : [])
        .accessibilityIdentifier("family.time_zone.mode.\(mode.rawValue)")
    }
}
