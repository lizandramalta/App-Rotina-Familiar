import SwiftUI

/// TEL-021 — fatia mínima (SPEC-014 Fase 2): título, observação, tarefas vinculadas e status.
/// Progresso, participações e recompensa pertencem a SPEC-016/017 (fora de escopo).
struct MissionDetailView: View {
    @State private var viewModel: MissionDetailViewModel
    let onRequestEdit: () -> Void
    let onSelectTask: (UUID) -> Void

    init(
        missionID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        accessToken: String,
        onRequestEdit: @escaping () -> Void,
        onSelectTask: @escaping (UUID) -> Void
    ) {
        _viewModel = State(initialValue: MissionDetailViewModel(
            missionID: missionID,
            role: role,
            currentMemberID: currentMemberID,
            repository: repository,
            taskRepository: taskRepository,
            accessToken: accessToken
        ))
        self.onRequestEdit = onRequestEdit
        self.onSelectTask = onSelectTask
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.mission == nil {
                ProgressView()
            } else if viewModel.loadFailed, viewModel.mission == nil {
                failureState
            } else if let mission = viewModel.mission {
                content(for: mission)
            } else {
                // Keeps the Group's branch always non-empty before `load()` sets `isLoading`
                // (same guard `TaskDetailView` uses — an empty Group can keep `.task` from firing).
                Color.clear
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("missions.detail.edit") {
                        onRequestEdit()
                    }
                    .accessibilityIdentifier("missions.detail.edit")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(for mission: Mission) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mission.title)
                        .font(.largeTitle.bold())
                    statusBadge(for: mission.status)
                }

                if let note = mission.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("missions.detail.note_title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(note)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.tasksSectionTitle(count: viewModel.linkedTasks.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(viewModel.linkedTasks) { task in
                            taskRow(task)
                            if task.id != viewModel.linkedTasks.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func taskRow(_ task: MissionTaskOption) -> some View {
        let isTappable = viewModel.canOpenTaskDetail(task)
        let row = HStack(spacing: 12) {
            statusIcon(for: task.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                Text(statusLabel(for: task.status))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isTappable {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(task.title), \(statusLabel(for: task.status))"))

        if isTappable {
            Button {
                onSelectTask(task.id)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("missions.detail.task_row.\(task.id.uuidString)")
        } else {
            row
                .accessibilityIdentifier("missions.detail.task_row.\(task.id.uuidString)")
        }
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("missions.detail.load_error", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("missions.common.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("missions.detail.load_error")
    }

    private func statusBadge(for status: MissionStatus) -> some View {
        Label(statusLabel(for: status), systemImage: status == .completed ? "checkmark.circle.fill" : "circle")
            .font(.subheadline)
            .foregroundStyle(status == .completed ? .green : .secondary)
    }

    private func statusIcon(for status: TaskStatus) -> some View {
        let (systemImage, color): (String, Color) = switch status {
        case .pending: ("circle", .secondary)
        case .awaitingConfirmation: ("clock", .orange)
        case .completed: ("checkmark.circle.fill", .green)
        }
        return Image(systemName: systemImage)
            .foregroundStyle(color)
    }

    private func statusLabel(for status: MissionStatus) -> String {
        switch status {
        case .inProgress: String(localized: "missions.status.in_progress")
        case .completed: String(localized: "missions.status.completed")
        }
    }

    /// Reusa as chaves de status já existentes em Tasks — mesmo texto ("Pendente"/"Concluída")
    /// usado por TEL-012, sem duplicar string para o mesmo conceito dentro do contexto da missão.
    private func statusLabel(for status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "tasks.personal.status.pending")
        case .awaitingConfirmation: String(localized: "tasks.personal.status.awaitingConfirmation")
        case .completed: String(localized: "tasks.detail.status_completed")
        }
    }

    private static func tasksSectionTitle(count: Int) -> String {
        String(format: String(localized: "missions.detail.tasks_section_title"), count)
    }
}
