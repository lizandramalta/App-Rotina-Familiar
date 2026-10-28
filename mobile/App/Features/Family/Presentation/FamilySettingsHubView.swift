import SwiftUI

/// TEL-057 — Configurações da família (Figma node 561:164). Admin-only hub for members and time zone.
struct FamilySettingsHubView: View {
    let viewModel: FamilyOverviewViewModel
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var editorViewModel: MemberEditorViewModel?
    @State private var isEditingFamilyName = false
    @State private var draftFamilyName = ""
    @State private var familyNameSaveFailed = false

    var body: some View {
        List {
            Section("family.settings.hub.family_section") {
                Button {
                    draftFamilyName = viewModel.familyName
                    isEditingFamilyName = true
                } label: {
                    settingsRow(icon: "house", title: "family.settings.hub.family_name", value: viewModel.familyName, showsChevron: true)
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("family.settings.hub.family_name")

                if familyNameSaveFailed {
                    Label("family.settings.hub.family_name_error", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("family.settings.hub.family_name_error")
                }

                if let makeFamilySettingsViewModel {
                    NavigationLink {
                        FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                    } label: {
                        settingsRow(icon: "globe", title: "family.settings.hub.timezone", value: viewModel.timeZoneDisplayName)
                    }
                    .accessibilityIdentifier("family.settings.hub.timezone")
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("family.members.error")
                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            Section {
                if viewModel.members.isEmpty && viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
                ForEach(viewModel.members) { member in
                    HStack(spacing: 8) {
                        NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                            row(member)
                        }
                        .accessibilityIdentifier("family.member.row.\(member.id.uuidString.lowercased())")
                    }
                    .task { await viewModel.loadMoreIfNeeded(currentMember: member) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if viewModel.loadMoreFailed {
                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadMore() }
                    }
                }
                if viewModel.canAddMember {
                    Button {
                        editorViewModel = viewModel.makeMemberEditorViewModel()
                    } label: {
                        Label("family.members.add.action", systemImage: "plus.circle.fill")
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("family.members.add.action")
                }
            } header: {
                Text(String(format: String(localized: "family.settings.hub.members_section"), viewModel.members.count))
            } footer: {
                Text("family.settings.hub.members_footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("family.settings.hub.title")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private func settingsRow(icon: String, title: LocalizedStringKey, value: String, showsChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .frame(minHeight: 44)
    }

    private func row(_ member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            Text(String(member.name.prefix(1)).uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 36, height: 36)
                .background(Color(uiColor: .secondarySystemFill), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.id == viewModel.currentMemberID ? "\(member.name) \(String(localized: "family.settings.hub.you"))" : member.name)
                    .font(.body)
                Text(roleLine(member))
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .frame(minHeight: 44)
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
