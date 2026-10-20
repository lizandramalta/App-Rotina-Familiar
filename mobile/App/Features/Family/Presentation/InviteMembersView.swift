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
        .sheet(item: $viewModel.generatedInvite) { generated in
            InviteCredentialsSheet(generated: generated)
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
        HStack(alignment: .center, spacing: 12) {
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

                HStack(spacing: 4) {
                    Text(member.role.onboardingTitleKey)
                    if viewModel.invites[member.id] != nil {
                        Text("·")
                        Text("convite gerado")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            // Invite Action Pill Button
            if viewModel.createdMembers[member.id] != nil {
                inviteButton(for: member)
            }
        }
        .padding(.horizontal, 16)
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
                } else {
                    Text(hasInvite ? "family.onboarding.invite_regenerate" : "family.onboarding.invite_generate")
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color(.label))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
}

private struct InviteCredentialsSheet: View {
    let generated: GeneratedInvite
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("family.onboarding.invite_link") {
                        Text(generated.invite.link)
                            .textSelection(.enabled)
                    }
                    LabeledContent("family.onboarding.invite_password") {
                        Text(generated.invite.password)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(generated.memberName)
                } footer: {
                    Text("family.onboarding.invite_sheet_footer")
                }

                Section {
                    ShareLink(item: shareText) {
                        Label("family.onboarding.invite_share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("family.onboarding.invite_sheet_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("family.onboarding.invite_close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var shareText: String {
        "\(generated.invite.link)\n\(generated.invite.password)"
    }
}
