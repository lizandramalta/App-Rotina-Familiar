import SwiftUI

/// TEL-056 — optional, explicit invite generation for the members created with the family.
/// Matches Figma 175:1132 design specifications.
struct InviteMembersView: View {
    @Bindable var viewModel: InitialOnboardingViewModel
    @State private var memberForRegeneration: DraftMember?

    var body: some View {
        ZStack {
            Color.clear
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("family.onboarding.invite_members")
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.onboarding.invite_header_title")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(.label))

                    Text("family.onboarding.invite_header_subtitle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                // Pending members error banner
                if viewModel.hasPendingMembers {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("family.onboarding.members_pending")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(.label))

                            Button("family.onboarding.members_retry") {
                                Task { await viewModel.retryPendingMembers() }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .disabled(viewModel.isCreatingMembers)
                            .accessibilityIdentifier("family.onboarding.members_retry")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Failed invite generation error banner
                if viewModel.inviteFailed {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color(.label))
                            .font(.system(size: 20))

                        Text("family.onboarding.invite_error")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.secondaryLabel))
                            .accessibilityIdentifier("family.onboarding.invite_error")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Members list section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Membros")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                            memberRow(for: member)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    Text("family.onboarding.invite_footer")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        }
        .accessibilityIdentifier("family.onboarding.invite_members")
        .onboardingColumn()
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !viewModel.path.isEmpty {
                        _ = viewModel.path.popLast()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Voltar")
                .accessibilityIdentifier("family.onboarding.back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    viewModel.finishOnboarding()
                } label: {
                    Text("family.onboarding.finish")
                        .font(.system(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule()
                                .fill(viewModel.hasGeneratedInvite ? Color.primary : Color(.systemGray5))
                        )
                        .foregroundStyle(viewModel.hasGeneratedInvite ? Color(.systemBackground) : Color(.systemGray))
                }
                .disabled(!viewModel.hasGeneratedInvite)
                .accessibilityIdentifier("family.onboarding.finish_invites")
                .accessibilityHint(viewModel.hasGeneratedInvite ? "" : "Indisponível - gere um convite primeiro")

                if !viewModel.hasGeneratedInvite {
                    Button {
                        viewModel.finishOnboarding()
                    } label: {
                        Text("family.onboarding.skip")
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(Color(.label))
                    }
                    .accessibilityIdentifier("family.onboarding.skip_invites")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
        .background {
            ActivityViewPresenter(
                generatedInvite: $viewModel.generatedInvite,
                messageBuilder: shareMessage(for:)
            )
        }
        .alert(
            "family.onboarding.invite_regenerate_confirm_title",
            isPresented: Binding(
                get: { memberForRegeneration != nil },
                set: { if !$0 { memberForRegeneration = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) {
                memberForRegeneration = nil
            }
            Button("family.onboarding.invite_regenerate") {
                if let member = memberForRegeneration {
                    memberForRegeneration = nil
                    Task { await viewModel.generateInvite(for: member.id) }
                }
            }
        } message: {
            if let member = memberForRegeneration {
                Text(String(
                    localized: "family.onboarding.invite_regenerate_confirm_message",
                    defaultValue: "Os convites anteriores de \(member.name) deixam de funcionar e o acesso atual dessa pessoa é encerrado."
                ))
            }
        }
    }

    // MARK: Member Row

    private func memberRow(for member: DraftMember) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Initial Avatar (36x36)
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(initialLetter(for: member.name))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                )

            // Info (Name & Role/Status)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 17))
                    .foregroundStyle(Color(.label))

                Text(roleDescription(for: member))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }
            .layoutPriority(1)

            Spacer()

            // Invite Action Pill Button
            if viewModel.createdMembers[member.id] != nil {
                inviteButton(for: member)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func inviteButton(for member: DraftMember) -> some View {
        let isGenerating = viewModel.invitesInFlight.contains(member.id)
        let hasInvite = viewModel.invites[member.id] != nil

        return Button {
            if hasInvite {
                memberForRegeneration = member
            } else {
                Task { await viewModel.generateInvite(for: member.id) }
            }
        } label: {
            HStack(spacing: 4) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Gerando...")
                        .lineLimit(1)
                } else {
                    Text(hasInvite ? "family.onboarding.invite_regenerate" : "family.onboarding.invite_generate")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color(.label))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
        }
        .disabled(isGenerating)
        .accessibilityIdentifier("family.onboarding.invite_button")
        .accessibilityLabel(
            hasInvite
                ? "Gerar novo convite para \(member.name)"
                : "Gerar convite para \(member.name)"
        )
    }

    private func initialLetter(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return ""
        }
        return String(first).uppercased()
    }

    private func roleDescription(for member: DraftMember) -> String {
        let roleName: String
        switch member.role {
        case .administrator:
            roleName = String(localized: "family.members.role.admin", defaultValue: "Administrador")
        case .member:
            roleName = String(localized: "family.members.role.member", defaultValue: "Membro")
        case .kid:
            roleName = String(localized: "family.members.role.kid", defaultValue: "Kids")
        }

        if viewModel.invites[member.id] != nil {
            return "\(roleName) · convite gerado"
        } else {
            return roleName
        }
    }

    private func shareMessage(for generated: GeneratedInvite) -> String {
        let template = String(
            localized: "family.onboarding.invite_share_message",
            defaultValue: "Convite para entrar na família no Rotina Familiar:\n\nLink: %@\nSenha: %@"
        )
        return String(format: template, generated.invite.link, generated.invite.password)
    }
}

private struct ActivityViewPresenter: UIViewControllerRepresentable {
    @Binding var generatedInvite: GeneratedInvite?
    let messageBuilder: (GeneratedInvite) -> String

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let generated = generatedInvite else {
            return
        }

        let message = messageBuilder(generated)
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        activityVC.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                self.generatedInvite = nil
            }
        }

        DispatchQueue.main.async {
            let presenter = self.topViewController(from: uiViewController)
            if presenter.presentedViewController is UIActivityViewController {
                return
            }

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            presenter.present(activityVC, animated: true)
        }
    }

    private func topViewController(from controller: UIViewController) -> UIViewController {
        if let windowScene = controller.view.window?.windowScene ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
           let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController ?? controller.view.window?.rootViewController {
            var current = root
            while let presented = current.presentedViewController, !presented.isBeingDismissed {
                current = presented
            }
            return current
        }
        var current = controller
        while let presented = current.presentedViewController, !presented.isBeingDismissed {
            current = presented
        }
        return current
    }
}
