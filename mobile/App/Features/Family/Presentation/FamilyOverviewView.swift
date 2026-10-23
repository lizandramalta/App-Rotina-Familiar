import SwiftUI

/// TEL-050 — Família (Figma nodes 372:4825, 372:5195, 561:173, UX-003 §5.1).
struct FamilyOverviewView: View {
    @State private var viewModel: FamilyOverviewViewModel
    @State private var editorViewModel: MemberEditorViewModel?
    private let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?

    init(
        viewModel: FamilyOverviewViewModel,
        makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
    }

    var body: some View {
        List {
            if viewModel.canAddMember {
                Section {
                    Button {
                        editorViewModel = viewModel.makeMemberEditorViewModel()
                    } label: {
                        Label("family.members.add.action", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("family.members.add.action")
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("family.members.error")

                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            Section("family.overview.members_section") {
                if viewModel.members.isEmpty && viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
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
            }
        }
        .accessibilityIdentifier("family.members.list")
        .navigationTitle("family.overview.title")
        .toolbar {
            if viewModel.canConfigureFamily, let makeFamilySettingsViewModel {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("family.settings.title")
                    .accessibilityIdentifier("family.navigation.settings_button")
                }
            }
        }
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
                .font(.headline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 40, height: 40)
                .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)
                Text(member.role.onboardingTitleKey)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Spacer()

            if member.isFamilyCreator {
                Text("family.members.creator_badge")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
