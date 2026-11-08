import SwiftUI

/// TEL-021 — Detalhe da missão (SPEC-016 Fase 2 / UX-016 §5.2): título/status, observação,
/// progresso canônico, tarefas vinculadas, recompensa e participações autorizadas. A ação de
/// resgate não existe aqui (UX-017 / SCRUM-90).
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
                skeleton
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

    /// Focus order follows UX-016 §8: título/status → observação → progresso → tarefas →
    /// recompensa → participações (quando autorizadas).
    @ViewBuilder
    private func content(for mission: MissionDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.refreshFailed {
                    MissionRefreshErrorBanner(
                        onRetry: { Task { await viewModel.load() } },
                        onDismiss: { viewModel.dismissRefreshError() }
                    )
                }

                banner(for: mission)

                if let note = mission.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .missionCard(cornerRadius: 14)
                        .accessibilityLabel(Text(verbatim: "\(String(localized: "missions.detail.note_title")): \(note)"))
                }

                trail(for: mission)

                if mission.status == .completed, let rewardState = viewModel.rewardState {
                    Text(MissionRewardText.text(for: rewardState))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .missionCard()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(MissionRewardText.text(for: rewardState)))
                        .accessibilityIdentifier("missions.detail.reward")
                }

                if let participations = viewModel.participations {
                    participationsBlock(participations)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        // UX-016 §6 `Refreshing`: discreet native indicator, confirmed content stays visible.
        .refreshable {
            await viewModel.load()
        }
    }

    /// Figma "Cabeçalho · banner da missão": title, remaining-tasks/completed line and the bar.
    private func banner(for mission: MissionDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mission.title)
                .font(viewModel.role == .kid ? .title.bold() : .title2.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                // Status in words for VoiceOver; shape/color is never the only cue (UX-016 §8).
                .accessibilityValue(Text(statusLabel(for: mission.status)))
            if let subtitle = viewModel.bannerSubtitle {
                Text(subtitle)
                    .font(viewModel.role == .kid ? .body.weight(.medium) : .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MissionProgressBar(
                completedTaskCount: mission.completedTaskCount,
                taskCount: mission.tasks.count,
                progressPercent: mission.progressPercent,
                height: viewModel.role == .kid ? 24 : 20,
                trackColor: Color(.systemBackground)
            )
            .accessibilityIdentifier("missions.detail.progress")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 22))
    }

    /// Figma "Trilha · tarefas até o baú (nós ≥ 72 pt)": zigzag nodes joined by a dotted path,
    /// ending at the chest. Under each title only the task state is shown — date and assignee are
    /// not in the detail contract (lacuna registrada, decisão de 2026-11-08).
    private func trail(for mission: MissionDetail) -> some View {
        let insets: [CGFloat] = [90, 30, 10, 50]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(mission.tasks.enumerated()), id: \.element.id) { index, task in
                let inset = insets[index % insets.count]
                if index > 0 {
                    connector(from: insets[(index - 1) % insets.count], to: inset)
                }
                trailNode(task, inset: inset)
            }
            if let chestState = viewModel.chestState {
                let last = mission.tasks.isEmpty ? 70 : insets[(mission.tasks.count - 1) % insets.count]
                connector(from: last, to: 70)
                MissionChestView(state: chestState, size: 84)
                    .padding(.leading, 70 - 6)
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func connector(from: CGFloat, to: CGFloat) -> some View {
        // Dotted segment between the centers of two consecutive 72 pt nodes.
        Path { path in
            path.move(to: CGPoint(x: from + 36, y: 0))
            path.addLine(to: CGPoint(x: to + 36, y: 34))
        }
        .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [0.1, 12]))
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func trailNode(_ task: MissionLinkedTask, inset: CGFloat) -> some View {
        let isTappable = viewModel.canOpenTaskDetail(task)
        let isOwn = viewModel.isOwnTask(task)
        let row = HStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .top) {
                nodeCircle(for: task.status, isOwn: isOwn)
                if isOwn {
                    Text(viewModel.role == .kid ? "missions.trail.own_task_kids" : "missions.trail.own_task")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.85), in: Capsule())
                        .fixedSize()
                        .offset(y: -22)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(viewModel.role == .kid ? .headline : .subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusLabel(for: task.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, inset)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(nodeAccessibilityLabel(task, isOwn: isOwn)))

        if isTappable {
            Button {
                onSelectTask(task.id)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("missions.detail.task_row.\(task.id.uuidString)")
        } else {
            row
                .accessibilityIdentifier("missions.detail.task_row.\(task.id.uuidString)")
        }
    }

    private func nodeAccessibilityLabel(_ task: MissionLinkedTask, isOwn: Bool) -> String {
        var parts = [task.title, statusLabel(for: task.status)]
        if isOwn {
            parts.append(String(localized: viewModel.role == .kid ? "missions.trail.own_task_kids" : "missions.trail.own_task"))
        }
        return parts.joined(separator: ", ")
    }

    /// Node states from Figma: done (filled + check), todo (gray + star), own (outlined + star).
    /// `awaitingConfirmation` is not drawn in Figma; it uses a clock so it never reads as done.
    private func nodeCircle(for status: TaskStatus, isOwn: Bool) -> some View {
        let (symbol, fill, foreground): (String, Color, Color) = switch status {
        case .completed: ("checkmark", Color.primary.opacity(0.8), Color(.systemBackground))
        case .awaitingConfirmation: ("clock", Color(.systemGray5), Color.primary.opacity(0.7))
        case .pending: ("star.fill", isOwn ? Color(.systemBackground) : Color(.systemGray5), isOwn ? Color.primary : Color(.systemGray2))
        }
        return ZStack {
            Circle()
                .fill(Color(.systemGray3))
                .offset(y: 4)
            Circle()
                .fill(fill)
            if isOwn, status != .completed {
                Circle().strokeBorder(Color.primary.opacity(0.85), lineWidth: 3)
            }
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(foreground)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }

    /// Figma "Quem já ajudou": initials avatars and the names joined (Admin/Membro only, CA-03).
    private func participationsBlock(_ participations: [MissionParticipation]) -> some View {
        let names = participations.map(\.displayName).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 10) {
            Text("missions.detail.participations_title")
                .textCase(.uppercase)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(participations) { participation in
                        MissionMemberAvatar(displayName: participation.displayName)
                    }
                }
                Text(names)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .missionCard(cornerRadius: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(names))
        }
        .padding(.top, 8)
        .accessibilityIdentifier("missions.detail.participations")
    }

    /// UX-016 §6 `Loading`: header and block skeleton; nothing incomplete is interactive.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(verbatim: "Placeholder mission title")
                .font(.largeTitle.bold())
            Text(verbatim: "Placeholder status")
            ProgressView(value: 0.5)
            ForEach(0 ..< 3, id: \.self) { _ in
                Text(verbatim: "Placeholder linked task")
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("missions.detail.loading"))
        .accessibilityIdentifier("missions.detail.loading")
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("mission.load.error", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("missions.common.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("missions.detail.load_error")
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
}
