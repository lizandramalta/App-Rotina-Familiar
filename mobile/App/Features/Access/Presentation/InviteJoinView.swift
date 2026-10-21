import SwiftUI

struct InviteJoinView: View {
    @Bindable var coordinator: InviteJoinCoordinator

    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.screen {
                case .password, .invalidPassword, .submitting:
                    passwordForm
                case .inspecting, .recovering:
                    progressContent
                case .unavailable:
                    messageContent(icon: "InvitePerson", title: "inviteJoin.error.unavailable", detail: nil)
                case .rateLimited:
                    messageContent(icon: "InvitePerson", title: "inviteJoin.error.rateLimited", detail: nil)
                case .recoveryUnavailable, .help:
                    recoveryContent
                case .recoveryRetryable:
                    messageContent(
                        icon: "InvitePerson",
                        title: "inviteJoin.recovery.inProgress",
                        detail: "access.common.error_network"
                    )
                case .networkFailure:
                    messageContent(icon: "InvitePerson", title: "access.common.error_network", detail: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(coordinator.screen == .help || coordinator.screen == .recoveryUnavailable
                             ? String(localized: "accessRecovery.title")
                             : String(localized: "inviteJoin.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !coordinator.screen.blocksDismissal {
                        Button {
                            coordinator.close()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel(Text("inviteJoin.back"))
                    }
                }
            }
        }
        .interactiveDismissDisabled(coordinator.screen.blocksDismissal)
    }

    private var passwordForm: some View {
        Form {
            Section {
                Text("inviteJoin.description")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("inviteJoin.password.label") {
                HStack(spacing: 12) {
                    Image("InviteLock")
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    SecureField("inviteJoin.password.label", text: $coordinator.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .privacySensitive()
                        .accessibilityLabel(Text("inviteJoin.password.accessibility"))
                        .accessibilityIdentifier("invite.join.password")
                        .disabled(coordinator.screen == .submitting)
                }
                if coordinator.screen == .invalidPassword {
                    Label("inviteJoin.error.invalidPassword", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.primary)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 2) {
                Button {
                    Task { await coordinator.submit() }
                } label: {
                    if coordinator.screen == .submitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("inviteJoin.submitting"))
                    } else {
                        Text("inviteJoin.submit")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(coordinator.password.isEmpty || coordinator.screen == .submitting)
                .accessibilityIdentifier("invite.join.submit")

                Button("inviteJoin.help.action") {
                    coordinator.showHelp()
                }
                .frame(minHeight: 44)
                .disabled(coordinator.screen == .submitting)
            }
            .frame(maxWidth: 540)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var progressContent: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(coordinator.screen == .recovering
                 ? "inviteJoin.recovery.inProgress" : "inviteJoin.inspecting")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    private var recoveryContent: some View {
        messageContent(
            icon: "InvitePerson",
            title: "accessRecovery.title",
            detail: coordinator.screen == .recoveryUnavailable
                ? "inviteJoin.recovery.unavailable"
                : "accessRecovery.invite.description",
            extraDetail: coordinator.screen == .recoveryUnavailable
                ? "accessRecovery.invite.description" : nil
        )
    }

    private func messageContent(
        icon: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey?,
        extraDetail: LocalizedStringKey? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Image(icon)
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let extraDetail {
                    Text(extraDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 24)
            Spacer()
            Button(actionTitle) {
                switch coordinator.screen {
                case .networkFailure:
                    Task { await coordinator.inspect() }
                case .recoveryRetryable:
                    Task { await coordinator.retryRecovery() }
                case .unavailable, .rateLimited:
                    coordinator.showHelp()
                default:
                    coordinator.close()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 540)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var actionTitle: LocalizedStringKey {
        switch coordinator.screen {
        case .networkFailure, .recoveryRetryable: "inviteJoin.retry"
        case .unavailable, .rateLimited: "inviteJoin.help.action"
        default: "accessRecovery.backToEntry"
        }
    }
}
