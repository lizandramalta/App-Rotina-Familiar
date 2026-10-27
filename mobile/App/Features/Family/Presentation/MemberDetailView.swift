import SwiftUI

/// TEL-032 — Detalhe do membro (Figma nodes 309:2057, 309:2219, 309:2281, UX-003 §5.2).
struct MemberDetailView: View {
    @State private var viewModel: MemberDetailViewModel
    @State private var showsReissueConfirmation = false
    @State private var showsNameEditor = false
    @State private var showsRolePicker = false
    @State private var showsRemovalConfirmation = false
    @State private var draftName = ""
    @Environment(\.dismiss) private var dismiss
    let onRemoved: () -> Void

    init(viewModel: MemberDetailViewModel, onRemoved: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onRemoved = onRemoved
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let detail = viewModel.detail {
                    identity(detail)
                    if viewModel.isCreator {
                        creatorNotice
                    }
                    if viewModel.canIssueInvite {
                        inviteSection
                    }
                    if viewModel.canManageTarget {
                        managementSection
                    }
                    if let taskViewModel = viewModel.taskViewModel {
                        FamilyTasksView(viewModel: taskViewModel)
                            .frame(minHeight: 360)
                    } else {
                        tasksPlaceholder
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .accessibilityIdentifier("family.member.detail.loading")
                }

                if let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Label {
                            Text(message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("family.member.detail.error")

                        Button("family.member.detail.retry") {
                            Task { await viewModel.load() }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("family.member.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $showsReissueConfirmation) {
            MemberInviteConfirmationView(viewModel: viewModel)
        }
        .inviteShareSheet(
            viewModel: viewModel,
            isPresented: viewModel.transientInvite != nil && !showsReissueConfirmation
        )
        .alert("family.member.manage.edit_name", isPresented: $showsNameEditor) {
            TextField("family.member.manage.name", text: $draftName)
            Button("family.settings.hub.cancel", role: .cancel) {}
            Button("family.settings.hub.save") { Task { await viewModel.updateName(draftName) } }
        }
        .confirmationDialog("family.member.manage.role", isPresented: $showsRolePicker) {
            ForEach(viewModel.allowedRoles, id: \.self) { role in
                Button(role.onboardingTitleKey) { Task { await viewModel.changeRole(role) } }
            }
        }
        .alert("family.member.manage.remove", isPresented: $showsRemovalConfirmation) {
            Button("family.settings.hub.cancel", role: .cancel) {}
            Button("family.member.manage.remove", role: .destructive) { Task { await viewModel.remove() } }
        } message: {
            Text("family.member.manage.remove_message")
        }
        .onChange(of: viewModel.isRemoved) { _, removed in
            if removed { onRemoved(); dismiss() }
        }
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("family.member.manage.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Button("family.member.manage.edit_name", systemImage: "pencil") {
                draftName = viewModel.detail?.name ?? ""
                showsNameEditor = true
            }
            Button("family.member.manage.role", systemImage: "person.crop.circle.badge.checkmark") {
                showsRolePicker = true
            }
            Button("family.member.manage.remove", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                showsRemovalConfirmation = true
            }
            if viewModel.isSaving { ProgressView() }
            if viewModel.managementFailed {
                Label("family.member.manage.error", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .disabled(viewModel.isSaving)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    /// UX-004 §5.1: first issuance is a direct tap; a previous invite routes to the TEL-034 confirmation.
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("family.member.detail.invite_section")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.hasPreviousInvite {
                    Button {
                        showsReissueConfirmation = true
                    } label: {
                        Label("memberInvite.reissue.title", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(viewModel.isIssuingInvite)
                    .accessibilityHint("memberInvite.a11y.action_hint")
                    .accessibilityIdentifier("memberInvite.reissue.title")
                } else {
                    Button {
                        Task { await viewModel.issueFirstInvite() }
                    } label: {
                        Label("memberInvite.issue.title", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(viewModel.isIssuingInvite)
                    .accessibilityIdentifier("memberInvite.issue.title")
                }

                if viewModel.isIssuingInvite {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("memberInvite.submitting")
                            .font(.footnote)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("memberInvite.submitting")
                }

                if let message = viewModel.inviteErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("memberInvite.error")
                }

                if viewModel.wasShareCancelled {
                    Label("memberInvite.share.cancelled", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .accessibilityIdentifier("memberInvite.share.cancelled")
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func identity(_ detail: FamilyMemberDetail) -> some View {
        VStack(spacing: 12) {
            Text(String(detail.name.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 80, height: 80)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .accessibilityHidden(true)

            Text(detail.name)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("family.member.detail.name")

            Text(detail.role.onboardingTitleKey)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .accessibilityIdentifier("family.member.detail.role")

            if detail.isFamilyCreator {
                Label {
                    Text("family.members.creator_badge")
                } icon: {
                    Image(systemName: "star.fill")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .accessibilityIdentifier("family.member.detail.creator_badge")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var creatorNotice: some View {
        Label {
            Text("family.members.creator_protected")
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.footnote)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("family.member.detail.creator_notice")
    }

    private var tasksPlaceholder: some View {
        Text("family.member.detail.tasks_placeholder")
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}
