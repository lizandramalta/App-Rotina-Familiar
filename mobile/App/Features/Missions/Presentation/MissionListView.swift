import SwiftUI

/// TEL-020 — fatia mínima da SPEC-014 Fase 2: duas seções, cada item só com título e status.
/// Progresso, participações e recompensa pertencem a SPEC-016/UX-016 (fora de escopo).
struct MissionListView: View {
    @State private var viewModel: MissionListViewModel
    let refreshRevision: Int
    let onSelectMission: (UUID) -> Void
    let onCreateMission: () -> Void

    init(
        repository: any MissionRepository,
        role: MemberRole,
        accessToken: String,
        refreshRevision: Int = 0,
        onSelectMission: @escaping (UUID) -> Void,
        onCreateMission: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: MissionListViewModel(repository: repository, role: role, accessToken: accessToken))
        self.refreshRevision = refreshRevision
        self.onSelectMission = onSelectMission
        self.onCreateMission = onCreateMission
    }

    private var isKidsPresentation: Bool {
        viewModel.role == .kid
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.isEmpty {
                ProgressView()
            } else if viewModel.loadFailed, viewModel.isEmpty {
                failureState
            } else if viewModel.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("missions.list.title")
        .toolbar {
            if viewModel.canCreate {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateMission()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("missions.list.create")
                    .accessibilityLabel(Text("missions.list.create_label"))
                }
            }
        }
        .task(id: refreshRevision) {
            await viewModel.load()
        }
    }

    private var list: some View {
        List {
            if !viewModel.inProgress.isEmpty {
                Section("missions.status.in_progress") {
                    ForEach(viewModel.inProgress) { mission in
                        row(for: mission)
                    }
                }
            }
            if !viewModel.completed.isEmpty {
                Section("missions.status.completed") {
                    ForEach(viewModel.completed) { mission in
                        row(for: mission)
                    }
                }
            }
        }
    }

    private func row(for mission: MissionSummary) -> some View {
        Button {
            onSelectMission(mission.id)
        } label: {
            HStack(spacing: 12) {
                statusIcon(for: mission.status)
                Text(mission.title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: isKidsPresentation ? 56 : 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(mission.title), \(statusLabel(for: mission.status))"))
        .accessibilityIdentifier("missions.list.row.\(mission.id.uuidString)")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("missions.list.empty_title", systemImage: "flag")
        } description: {
            Text("missions.list.empty_description")
        } actions: {
            if viewModel.canCreate {
                Button("missions.list.empty_action") {
                    onCreateMission()
                }
            }
        }
        .accessibilityIdentifier("missions.list.empty")
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("missions.list.load_error", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("missions.common.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("missions.list.load_error")
    }

    private func statusIcon(for status: MissionStatus) -> some View {
        let (systemImage, color): (String, Color) = switch status {
        case .inProgress: ("circle", .secondary)
        case .completed: ("checkmark.circle.fill", .green)
        }
        return Image(systemName: systemImage)
            .foregroundStyle(color)
            .font(isKidsPresentation ? .title2 : .title3)
    }

    private func statusLabel(for status: MissionStatus) -> String {
        switch status {
        case .inProgress: String(localized: "missions.status.in_progress")
        case .completed: String(localized: "missions.status.completed")
        }
    }
}
