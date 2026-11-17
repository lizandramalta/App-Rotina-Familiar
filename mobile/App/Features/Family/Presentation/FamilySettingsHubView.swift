import SwiftUI

/// TEL-057 — Configurações da família (Figma node 561:164). Admin-only hub for members and time zone.
struct FamilySettingsHubView: View {
    let viewModel: FamilyOverviewViewModel
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var editorViewModel: MemberEditorViewModel?
    @State private var isEditingFamilyName = false
    @State private var draftFamilyName = ""
    @State private var familyNameSaveFailed = false
    @State private var editingKid: FamilyMember?
    @State private var draftKidName = ""
    @State private var kidNameIsInvalid = false
    @State private var kidNameSaveFailed = false
    @State private var kidNameRequiresRefresh = false
    @State private var kidNameIsSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                familySection
                if let message = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        FamilyNoticeCard(message, tone: .error)
                            .accessibilityIdentifier("family.members.error")
                        Button("family.member.detail.retry") {
                            Task { await viewModel.loadInitial() }
                        }
                        .font(.app(.subtitleStrong))
                        .foregroundStyle(Color.App.Text.highlight)
                        .frame(minHeight: 44)
                        .padding(.leading, AppSpacing.lg)
                        .disabled(viewModel.isLoading)
                    }
                }
                membersSection
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("family.settings.hub.title")
        .navigationBarTitleDisplayMode(.inline)
        .hidesAppTabBar()
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
        .alert("family.settings.hub.family_name", isPresented: $isEditingFamilyName) {
            TextField("family.settings.hub.family_name", text: $draftFamilyName)
            Button("family.settings.hub.cancel", role: .cancel) {}
            Button("family.settings.hub.save") {
                Task {
                    do {
                        try await viewModel.updateFamilyName(draftFamilyName)
                        familyNameSaveFailed = false
                    } catch {
                        familyNameSaveFailed = true
                    }
                }
            }
        } message: {
            Text("family.settings.hub.family_name_hint")
        }
        .sheet(isPresented: Binding(get: { editorViewModel != nil }, set: { if !$0 { editorViewModel = nil } })) {
            if let editorViewModel {
                NavigationStack {
                    MemberEditorView(viewModel: editorViewModel) {
                        Task { await viewModel.memberCreated() }
                    }
                }
            }
        }
        .sheet(item: $editingKid) { kid in
            NavigationStack { kidsNameEditor(for: kid) }
        }
    }

    // MARK: Família

    private var familySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.settings.hub.family_section")
            VStack(spacing: 0) {
                Button {
                    draftFamilyName = viewModel.familyName
                    isEditingFamilyName = true
                } label: {
                    settingsRow(icon: "house", title: "family.settings.hub.family_name", value: viewModel.familyName)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("family.settings.hub.family_name")

                if let makeFamilySettingsViewModel {
                    FamilyCardSeparator(leadingInset: AppSpacing.lg + 24 + AppSpacing.md)
                    NavigationLink {
                        FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                            .hidesAppTabBar()
                    } label: {
                        settingsRow(icon: "globe", title: "family.settings.hub.timezone", value: viewModel.timeZoneDisplayName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.settings.hub.timezone")
                }
            }
            .appCard(cornerRadius: AppRadius.pill)

            if familyNameSaveFailed {
                FamilyNoticeCard("family.settings.hub.family_name_error", tone: .error)
                    .accessibilityIdentifier("family.settings.hub.family_name_error")
            }
        }
    }

    // MARK: Membros

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel(verbatim: String(
                format: String(localized: "family.settings.hub.members_section"), viewModel.members.count
            ))
            VStack(spacing: 0) {
                if viewModel.members.isEmpty && viewModel.isLoading {
                    ForEach(0..<2, id: \.self) { index in
                        if index > 0 { FamilyCardSeparator() }
                        HStack(spacing: AppSpacing.md) {
                            Circle().fill(Color.App.Background.subtle).frame(width: 36, height: 36)
                            Capsule().fill(Color.App.Background.subtle).frame(width: 140, height: 14)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(minHeight: 60)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("family.overview.loading")
                }
                ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                    if index > 0 { FamilyCardSeparator(leadingInset: AppSpacing.lg + 36 + AppSpacing.md) }
                    memberRow(member)
                        .task { await viewModel.loadMoreIfNeeded(currentMember: member) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().tint(Color.App.Action.primary).frame(maxWidth: .infinity, minHeight: 44)
                }
                if viewModel.loadMoreFailed {
                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadMore() }
                    }
                    .font(.app(.subtitleStrong))
                    .foregroundStyle(Color.App.Text.highlight)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                if viewModel.canAddMember {
                    FamilyCardSeparator()
                    Button {
                        editorViewModel = viewModel.makeMemberEditorViewModel()
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.App.Action.primary)
                                .frame(width: 36)
                                .accessibilityHidden(true)
                            Text("family.members.add.action")
                                .font(.app(.bodyStrong))
                                .foregroundStyle(Color.App.Text.primary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.members.add.action")
                }
            }
            .appCard(cornerRadius: AppRadius.pill)

            Text("family.settings.hub.members_footer")
                .font(.app(.note))
                .foregroundStyle(Color.App.Text.secondary)
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        HStack(spacing: AppSpacing.xs) {
            NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                row(member)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("family.member.row.\(member.id.uuidString.lowercased())")
            if viewModel.canConfigureFamily && member.role == .kid {
                Button {
                    draftKidName = member.name
                    kidNameIsInvalid = false
                    kidNameSaveFailed = false
                    kidNameRequiresRefresh = false
                    editingKid = member
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.App.Action.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("family.settings.hub.edit_kids_name")
                .accessibilityIdentifier("family.settings.hub.edit_kids_name.\(member.id.uuidString.lowercased())")
            }
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.sm)
    }

    private func kidsNameEditor(for kid: FamilyMember) -> some View {
        FamilyKidsNameEditor(
            name: $draftKidName,
            fieldIdentifier: "family.settings.hub.kids_name",
            isInvalid: kidNameIsInvalid,
            showsError: kidNameSaveFailed,
            requiresRefresh: kidNameRequiresRefresh,
            isSaving: kidNameIsSaving,
            hasChanges: draftKidName != kid.name,
            onRetry: {
                Task {
                    if let current = await viewModel.refreshMember(memberID: kid.id) {
                        kidNameRequiresRefresh = false
                        kidNameSaveFailed = current.role != .kid
                    }
                }
            },
            onSave: { saveKidName(kid) },
            onClose: { editingKid = nil }
        )
        .onChange(of: draftKidName) { _, _ in kidNameIsInvalid = false }
    }

    private func saveKidName(_ kid: FamilyMember) {
        guard case .success = FamilyCreationValidation.validatedName(draftKidName) else {
            kidNameIsInvalid = true
            return
        }
        kidNameIsSaving = true
        kidNameSaveFailed = false
        Task {
            let result = await viewModel.updateKidsName(
                memberID: kid.id,
                name: draftKidName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            kidNameIsSaving = false
            switch result {
            case .saved: editingKid = nil
            case .failed, .noLongerEligible: kidNameSaveFailed = true
            case .reconciliationRequired: kidNameRequiresRefresh = true
            }
        }
    }

    private func settingsRow(icon: String, title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.App.Action.primary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.primary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(.app(.subtitle))
                .foregroundStyle(Color.App.Text.secondary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private func row(_ member: FamilyMember) -> some View {
        HStack(spacing: AppSpacing.md) {
            MemberAvatarView(
                name: member.name,
                color: FamilyMemberPalette.colors(
                    for: member.id, isCurrentMember: member.id == viewModel.currentMemberID
                ).tint,
                size: 36
            )
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(member.id == viewModel.currentMemberID ? "\(member.name) \(String(localized: "family.settings.hub.you"))" : member.name)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                Text(roleLine(member))
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func roleLine(_ member: FamilyMember) -> String {
        let role = switch member.role {
        case .administrator: String(localized: "family.member.role.administrator")
        case .member: String(localized: "family.member.role.member")
        case .kid: String(localized: "family.member.role.kids")
        }
        return member.isFamilyCreator
            ? String(format: String(localized: "family.settings.hub.creator_role"), role)
            : role
    }
}
