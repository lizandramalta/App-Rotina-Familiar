import SwiftUI

/// TEL-053 — Configurações da família (fuso horário).
/// Apresenta o fuso vigente da família, eventual alteração programada,
/// seletor de novo fuso e botão primário "Aplicar" que abre MOD-012.
/// Membro e Kids não possuem acesso e recebem aviso de acesso restrito.
struct FamilySettingsView: View {
    @StateObject var viewModel: FamilySettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingSkeleton
            case .accessDenied:
                stateCard(
                    symbol: "lock.shield",
                    title: "family.settings.access_denied_title",
                    message: Text("family.settings.access_denied_description"),
                    showsRetry: false
                )
                .accessibilityIdentifier("family.settings.access_denied")
            case let .error(message):
                stateCard(
                    symbol: "wifi.exclamationmark",
                    title: "family.common.error_network",
                    message: Text(message),
                    showsRetry: true
                )
            case let .loaded(settings):
                content(settings)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("family.settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .hidesAppTabBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .fontWeight(.semibold)
                }
                .tint(Color.App.Text.primary)
                .accessibilityLabel("family.tasks.back")
                .accessibilityIdentifier("family.settings.back_button")
            }
        }
        .accessibilityIdentifier("family.settings.view")
        .task {
            if viewModel.state == .idle {
                await viewModel.loadSettings()
            }
        }
        .sheet(isPresented: $viewModel.isConfirmationPresented) {
            FamilyTimeZoneConfirmationSheetView(viewModel: viewModel)
                .presentationDetents([.large])
        }
    }

    private var loadingSkeleton: some View {
        VStack(spacing: AppSpacing.xxl) {
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .fill(Color.App.Background.subtle)
                .frame(height: 110)
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .fill(Color.App.Background.subtle)
                .frame(height: 260)
            Spacer()
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: 540)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.settings.loading")
    }

    private func stateCard(symbol: String, title: LocalizedStringKey, message: Text, showsRetry: Bool) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Color.App.Action.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(.app(.title3))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.center)
            message
                .font(.app(.subtitle))
                .foregroundStyle(Color.App.Text.secondary)
                .multilineTextAlignment(.center)
            if showsRetry {
                Button("family.member.detail.retry") {
                    Task { await viewModel.loadSettings() }
                }
                .buttonStyle(AppPillButtonStyle(kind: .primary))
            }
        }
        .padding(AppSpacing.xxl)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .padding(AppSpacing.xxl)
        .frame(maxWidth: 540)
    }

    @ViewBuilder
    private func content(_ settings: FamilySettings) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                if let notice = viewModel.successNotice {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.App.Text.primary)
                            .accessibilityHidden(true)
                        Text(notice)
                            .font(.app(.subtitle))
                            .foregroundStyle(Color.App.Text.primary)
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.App.Background.cardHighlight, in: RoundedRectangle(cornerRadius: AppRadius.pill))
                    .chalkStrokeBorder(RoundedRectangle(cornerRadius: AppRadius.pill), color: Color.App.Border.card, lineWidth: 1.5)
                    .accessibilityElement(children: .combine)
                }

                if let error = viewModel.errorMessage, !viewModel.isConfirmationPresented {
                    InlineFeedbackBanner(message: error)
                }

                currentSection(settings)
                newTimeZoneSection(settings)
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await viewModel.requestPreview()
                }
            } label: {
                if viewModel.isPreviewLoading {
                    ProgressView().tint(Color.App.Text.onAction)
                } else {
                    Text("family.settings.time_zone.preview")
                }
            }
            .buttonStyle(AppPillButtonStyle(kind: .primary))
            .disabled(!viewModel.canRequestPreview)
            .accessibilityIdentifier("family.settings.preview_button")
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .background(Color.App.Background.app)
        }
    }

    private func currentSection(_ settings: FamilySettings) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.settings.section.current_time_zone")
            VStack(spacing: 0) {
                valueRow(
                    label: "family.settings.time_zone.current",
                    value: TimeZoneDisplay.displayName(for: settings.timeZoneID)
                )
                .accessibilityIdentifier("family.settings.current_timezone")
                if let scheduled = settings.scheduledTimeZoneChange {
                    FamilyCardSeparator()
                    valueRow(
                        label: "family.settings.scheduled_change",
                        value: "\(TimeZoneDisplay.displayName(for: scheduled.timeZoneID)) · \(String(localized: "family.settings.scheduled_badge"))"
                    )
                    .accessibilityIdentifier("family.settings.scheduled_change")
                }
            }
            .appCard(cornerRadius: AppRadius.pill)
            sectionFooter(settings.limits.isTransition ? "family.settings.transition_footer" : "family.settings.help_footer")
        }
    }

    private func newTimeZoneSection(_ settings: FamilySettings) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.settings.section.new_time_zone")
            VStack(spacing: 0) {
                ForEach(Array(TimeZoneDisplay.standardOptions.enumerated()), id: \.element.id) { index, option in
                    if index > 0 { FamilyCardSeparator() }
                    timeZoneRow(option: option, settings: settings)
                }
            }
            .appCard(cornerRadius: AppRadius.pill)
            sectionFooter("family.settings.selection_footer")
        }
    }

    private func valueRow(label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(label)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.secondary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(.app(.subtitleStrong))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private func sectionFooter(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.app(.note))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.horizontal, AppSpacing.lg)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func timeZoneRow(option: FamilyTimeZoneOption, settings: FamilySettings) -> some View {
        let isCurrent = viewModel.isTimeZoneCurrent(option.identifier)
        let isScheduled = viewModel.isTimeZoneScheduled(option.identifier)
        let isDisabled = viewModel.isTimeZoneDisabled(option.identifier)
        let isSelected = viewModel.selectedTimeZoneID == option.identifier

        Button {
            viewModel.selectTimeZone(option.identifier)
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(option.name)
                            .font(.app(.body))
                            .foregroundStyle(isDisabled ? Color.App.Text.secondary : Color.App.Text.primary)
                        if isCurrent || isScheduled {
                            Text("· \(String(localized: isCurrent ? "family.settings.current_badge" : "family.settings.scheduled_badge"))")
                                .font(.app(.note))
                                .foregroundStyle(Color.App.Text.secondary)
                        }
                    }
                    Text(option.subtitle)
                        .font(.app(.caption))
                        .foregroundStyle(Color.App.Text.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier("family.settings.timezone_option.\(option.identifier)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
