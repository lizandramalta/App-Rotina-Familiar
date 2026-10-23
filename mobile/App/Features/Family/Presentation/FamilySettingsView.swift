import SwiftUI

/// TEL-053 — Configurações da família (fuso horário).
/// Apresenta o fuso vigente da família, eventual alteração programada,
/// seletor de novo fuso e botão primário "Ver efeitos" que abre MOD-012.
/// Membro e Kids não possuem acesso e recebem aviso de acesso restrito.
struct FamilySettingsView: View {
    @StateObject var viewModel: FamilySettingsViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("family.settings.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .accessDenied:
                ContentUnavailableView {
                    Label("family.settings.access_denied_title", systemImage: "lock.shield")
                } description: {
                    Text("family.settings.access_denied_description")
                }
                .accessibilityIdentifier("family.settings.access_denied")
            case let .error(message):
                ContentUnavailableView {
                    Label("family.common.error_network", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Tentar novamente") {
                        Task {
                            await viewModel.loadSettings()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case let .loaded(settings):
                content(settings)
            }
        }
        .navigationTitle("family.settings.title")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func content(_ settings: FamilySettings) -> some View {
        Form {
            if let notice = viewModel.successNotice {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(notice)
                            .font(.subheadline)
                    }
                }
            }

            if let error = viewModel.errorMessage, !viewModel.isConfirmationPresented {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                LabeledContent {
                    Text(TimeZoneDisplay.displayName(for: settings.timeZoneID))
                        .foregroundStyle(.primary)
                } label: {
                    Text("family.settings.time_zone.current")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("family.settings.current_timezone")

                if let scheduled = settings.scheduledTimeZoneChange {
                    LabeledContent {
                        Text("\(TimeZoneDisplay.displayName(for: scheduled.timeZoneID)) (próximo ciclo)")
                            .foregroundStyle(.primary)
                    } label: {
                        Text("family.settings.scheduled_change")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("family.settings.scheduled_change")
                }
            } header: {
                Text("family.settings.section.current_time_zone")
            } footer: {
                if settings.limits.isTransition {
                    Text("family.settings.transition_footer")
                } else {
                    Text("family.settings.help_footer")
                }
            }

            Section {
                ForEach(TimeZoneDisplay.standardOptions) { option in
                    timeZoneRow(option: option, settings: settings)
                }
            } header: {
                Text("family.settings.section.new_time_zone")
            } footer: {
                Text("family.settings.selection_footer")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await viewModel.requestPreview()
                }
            } label: {
                HStack {
                    if viewModel.isPreviewLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("family.settings.time_zone.preview")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.canRequestPreview ? Color.accentColor : Color.secondary.opacity(0.3))
                .foregroundStyle(viewModel.canRequestPreview ? Color.white : Color.secondary)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRequestPreview)
            .accessibilityIdentifier("family.settings.preview_button")
        }
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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                        .font(.body)
                    Text(option.subtitle)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                } else if isCurrent {
                    Text("family.settings.current_badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isScheduled {
                    Text("family.settings.scheduled_badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier("family.settings.timezone_option.\(option.identifier)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
