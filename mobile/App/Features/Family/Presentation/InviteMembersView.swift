import SwiftUI

/// TEL-056 — optional, explicit invite generation for the members created with the family.
struct InviteMembersView: View {
    @Bindable var viewModel: InitialOnboardingViewModel

    var body: some View {
        List {
            if viewModel.hasPendingMembers {
                Section {
                    Label("family.onboarding.members_pending", systemImage: "exclamationmark.triangle")
                    Button("family.onboarding.members_retry") {
                        Task { await viewModel.retryPendingMembers() }
                    }
                    .disabled(viewModel.isCreatingMembers)
                    .accessibilityIdentifier("family.onboarding.members_retry")
                }
            }

            Section {
                ForEach(viewModel.members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                            RoleBadge(role: member.role)
                        }
                        Spacer()
                        if viewModel.createdMembers[member.id] != nil {
                            inviteButton(for: member)
                        }
                    }
                }
            } footer: {
                if viewModel.inviteFailed {
                    FieldErrorText(
                        key: "family.onboarding.invite_error",
                        identifier: "family.onboarding.invite_error"
                    )
                } else {
                    Text("family.onboarding.invite_footer")
                }
            }
        }
        .accessibilityIdentifier("family.onboarding.invite_members")
        .onboardingColumn()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("family.onboarding.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button("family.onboarding.skip") {
                    viewModel.finishOnboarding()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("family.onboarding.skip_invites")

                OnboardingPrimaryButton(title: "family.onboarding.finish", identifier: "family.onboarding.finish_invites") {
                    viewModel.finishOnboarding()
                }
                .disabled(!viewModel.hasGeneratedInvite)
            }
            .background(.bar)
        }
        .sheet(item: $viewModel.generatedInvite) { generated in
            InviteCredentialsSheet(generated: generated)
        }
    }

    private func inviteButton(for member: DraftMember) -> some View {
        Button {
            Task { await viewModel.generateInvite(for: member.id) }
        } label: {
            if viewModel.invitesInFlight.contains(member.id) {
                ProgressView()
            } else {
                Text(viewModel.invites[member.id] == nil ? "family.onboarding.invite_generate" : "family.onboarding.invite_regenerate")
            }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.invitesInFlight.contains(member.id))
        .accessibilityIdentifier("family.onboarding.invite_button")
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
