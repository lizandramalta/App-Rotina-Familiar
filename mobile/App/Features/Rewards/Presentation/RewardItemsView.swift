import SwiftUI

/// TEL-023 — catálogo de recompensas coletivas (SPEC-015 Fase 1). Reached only from TEL-020,
/// Administrador apenas (RN41/42, CA-05) — Membro/Kids never get a path here.
struct RewardItemsView: View {
    @State private var viewModel: RewardItemsViewModel
    let repository: any RewardRepository
    let accessToken: String

    init(repository: any RewardRepository, role: MemberRole, accessToken: String, allowsManagement: Bool = true) {
        _viewModel = State(initialValue: RewardItemsViewModel(
            repository: repository,
            role: role,
            accessToken: accessToken,
            allowsManagement: allowsManagement
        ))
        self.repository = repository
        self.accessToken = accessToken
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.predefined.isEmpty, viewModel.custom.isEmpty {
                ProgressView()
            } else if viewModel.loadFailed, viewModel.predefined.isEmpty, viewModel.custom.isEmpty {
                failureState
            } else {
                list
            }
        }
        .navigationTitle("rewards.items.title")
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.openAddItem()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("rewards.items.add")
                    .accessibilityLabel(Text("rewards.items.add"))
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isAddItemPresented) {
            RewardItemEditorView(
                repository: repository,
                accessToken: accessToken,
                onSaved: { _ in Task { await viewModel.handleItemSaved() } },
                onUncertain: { viewModel.handleUncertainOutcome() }
            )
        }
        .task {
            await viewModel.load()
        }
    }

    private var list: some View {
        List {
            if viewModel.showsUncertainBanner {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("rewards.items.uncertain")
                            .foregroundStyle(.secondary)
                        Button("rewards.items.refresh") {
                            Task { await viewModel.refreshAfterUncertain() }
                        }
                    }
                }
                .accessibilityIdentifier("rewards.items.uncertain_banner")
            }

            Section("rewards.items.section.predefined") {
                ForEach(viewModel.predefined) { item in
                    row(for: item)
                }
            }

            Section {
                if viewModel.isCustomEmpty {
                    Text("rewards.items.custom.empty")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("rewards.items.custom.empty")
                } else {
                    ForEach(viewModel.custom) { item in
                        row(for: item)
                    }
                }
            } header: {
                Text("rewards.items.section.custom")
            }
        }
    }

    private func row(for item: RewardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
            if let details = item.details, !details.isEmpty {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(badgeLabel(for: item.source))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rewards.items.row.\(item.id.uuidString)")
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("rewards.items.load_error", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("missions.common.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("rewards.items.load_error")
    }

    private func badgeLabel(for source: RewardItemSource) -> String {
        switch source {
        case .predefined: String(localized: "rewards.items.badge.predefined")
        case .custom: String(localized: "rewards.items.badge.custom")
        }
    }
}
