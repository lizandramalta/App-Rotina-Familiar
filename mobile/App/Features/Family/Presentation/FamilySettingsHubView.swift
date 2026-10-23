import SwiftUI

/// TEL-057 — Configurações da família (Figma node 561:164). Admin-only hub for members and time zone.
struct FamilySettingsHubView: View {
    let viewModel: FamilyOverviewViewModel
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var editorViewModel: MemberEditorViewModel?

    var body: some View {
        List {
            if let makeFamilySettingsViewModel {
                Section("family.settings.hub.family_section") {
                    NavigationLink {
                        FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                    } label: {
                        Text("family.settings.hub.timezone")
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
                    NavigationLink {
                        MemberDetailView(viewModel: viewModel.makeMemberDetailViewModel(memberID: member.id))
                    } label: {
                        row(member)
                    }
                    .accessibilityIdentifier("family.member.row.\(member.id.uuidString.lowercased())")
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
                    .accessibilityIdentifier("family.members.add.action")
                }
            } header: {
                Text("family.settings.hub.members_section \(viewModel.members.count)")
            } footer: {
                Text("family.settings.hub.members_footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("family.settings.hub.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
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
