import SwiftUI

/// TEL-021 — Detalhe da missão (SPEC-016 Fases 2 e 3 / UX-016 §5.2), em alta fidelidade
/// (Figma 907-14795): faixa da missão, observação, trilha de tarefas até o baú com data e
/// responsáveis (CA-08), recompensa e participações autorizadas. Administrador de missão concluída
/// e resgatável vê "Resgatar recompensa", que abre TEL-024 (SPEC-017 Fase 2).
struct MissionDetailView: View {
    @State private var viewModel: MissionDetailViewModel
    let onRequestEdit: () -> Void
    let onSelectTask: (UUID) -> Void
    let onRedeem: (MissionDetail) -> Void
    /// Bumped by the host after TEL-024 so the canonical detail is reloaded (UX-017 §4).
    let refreshRevision: Int

    init(
        missionID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        accessToken: String,
        onRequestEdit: @escaping () -> Void,
        onSelectTask: @escaping (UUID) -> Void,
        onRedeem: @escaping (MissionDetail) -> Void = { _ in },
        refreshRevision: Int = 0
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
        self.onRedeem = onRedeem
        self.refreshRevision = refreshRevision
    }

    private var isKids: Bool { viewModel.role == .kid }

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
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Figma: only the Liquid Glass back button and the "Editar" pill float over the page.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if viewModel.canEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onRequestEdit()
                    } label: {
                        Text("missions.detail.edit")
                            .font(.app(.body))
                            .foregroundStyle(Color.App.Text.primary)
                    }
                    .accessibilityIdentifier("missions.detail.edit")
                }
            }
        }
        .task(id: refreshRevision) {
            await viewModel.load()
        }
    }

    /// Focus order follows UX-016 §8: título/status → observação → progresso → tarefas →
    /// recompensa → participações (quando autorizadas).
    private func content(for mission: MissionDetail) -> some View {
        // The root reader's width is the screen's, never the content's, so placing the zigzag from
        // it cannot feed back into layout (measuring the trail itself looped on some layouts).
        GeometryReader { proxy in
            scrollContent(for: mission, trailWidth: max(proxy.size.width - 2 * AppSpacing.xxl, 0))
        }
    }

    @ViewBuilder
    private func scrollContent(for mission: MissionDetail, trailWidth: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if viewModel.refreshFailed {
                    MissionRefreshErrorBanner(
                        onRetry: { Task { await viewModel.load() } },
                        onDismiss: { viewModel.dismissRefreshError() }
                    )
                }

                banner(for: mission)

                if let note = mission.note, !note.isEmpty {
                    Text(note)
                        .font(.app(isKids ? .body : .subtitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.base)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .missionDetailCard()
                        .accessibilityLabel(Text(verbatim: "\(String(localized: "missions.detail.note_title")): \(note)"))
                }

                trail(for: mission, width: trailWidth)

                if mission.status == .completed, let rewardState = viewModel.rewardState {
                    Text(MissionRewardText.text(for: rewardState))
                        .font(.app(.cardTitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(AppSpacing.xl)
                        .frame(maxWidth: .infinity)
                        .missionDetailCard()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(MissionRewardText.text(for: rewardState)))
                        .accessibilityIdentifier("missions.detail.reward")
                }

                if viewModel.canRedeem {
                    Button {
                        onRedeem(mission)
                    } label: {
                        Label("mission.reward.redeem", systemImage: "gift")
                    }
                    .buttonStyle(AppPillButtonStyle(kind: .primary))
                    .accessibilityIdentifier("missions.detail.redeem")
                }

                if let participations = viewModel.participations {
                    participationsBlock(participations)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.giant)
        }
        // UX-016 §6 `Refreshing`: discreet native indicator, confirmed content stays visible.
        .refreshable {
            await viewModel.load()
        }
    }

    /// Figma "Cabeçalho · banner da missão": title, remaining-tasks/completed line and the bar,
    /// with the decorative star sticker on the trailing edge.
    private func banner(for mission: MissionDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(mission.title)
                .font(.app(isKids ? .title1 : .title2))
                .foregroundStyle(Color.App.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, AppSpacing.giant)
                .accessibilityAddTraits(.isHeader)
                // Status in words for VoiceOver; shape/color is never the only cue (UX-016 §8).
                .accessibilityValue(Text(statusLabel(for: mission.status)))
            if let subtitle = viewModel.bannerSubtitle {
                Text(subtitle)
                    .font(.app(isKids ? .bodyStrong : .subtitleStrong))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MissionProgressBar(
                completedTaskCount: mission.completedTaskCount,
                taskCount: mission.tasks.count,
                progressPercent: mission.progressPercent,
                height: isKids ? 24 : 20
            )
            .padding(.top, AppSpacing.xs)
            .accessibilityIdentifier("missions.detail.progress")
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.App.Background.subtle, in: RoundedRectangle(cornerRadius: AppRadius.cardBoard))
        .overlay(alignment: .topTrailing) {
            StarDecorationView(variant: .blue, size: 46)
                .offset(x: -AppSpacing.sm, y: AppSpacing.huge)
        }
    }

    // MARK: - Trail

    /// Horizontal anchors (fraction of the trail width) of each node, read from Figma 907-14795:
    /// the zigzag repeats every four tasks and the chest sits near the first node.
    private static let nodeAnchors: [CGFloat] = [0.35, 0.16, 0.10, 0.27]
    private static let chestAnchor: CGFloat = 0.36
    private static let nodeSize: CGFloat = 72
    private static let connectorHeight: CGFloat = 44

    private func nodeInset(at index: Int, width: CGFloat) -> CGFloat {
        let labelReserve: CGFloat = 150
        let maxInset = max(width - Self.nodeSize - labelReserve, 0)
        return min(width * Self.nodeAnchors[index % Self.nodeAnchors.count], maxInset)
    }

    /// Figma "Trilha · tarefas até o baú (nós ≥ 72 pt)": zigzag nodes joined by a dotted path,
    /// ending at the chest. Under each title: date/state and assignees (CA-08, UX-10).
    private func trail(for mission: MissionDetail, width trailWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(mission.tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    MissionTrailDots(
                        fromX: nodeInset(at: index - 1, width: trailWidth) + Self.nodeSize / 2,
                        toX: nodeInset(at: index, width: trailWidth) + Self.nodeSize / 2
                    )
                    .frame(height: Self.connectorHeight)
                }
                trailNode(task, inset: nodeInset(at: index, width: trailWidth))
            }
            if let chestState = viewModel.chestState {
                let chestSize: CGFloat = 84
                let chestInset = min(trailWidth * Self.chestAnchor, max(trailWidth - chestSize, 0))
                let lastCenter = mission.tasks.isEmpty
                    ? chestInset + chestSize / 2
                    : nodeInset(at: mission.tasks.count - 1, width: trailWidth) + Self.nodeSize / 2
                MissionTrailDots(fromX: lastCenter, toX: chestInset + chestSize / 2)
                    .frame(height: Self.connectorHeight)
                MissionChestView(state: chestState, size: chestSize)
                    .padding(.leading, chestInset)
            }
        }
        // Room for the titular balloon above the first node, so it is never clipped (UX-13).
        .padding(.top, AppSpacing.giant)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func trailNode(_ task: MissionLinkedTask, inset: CGFloat) -> some View {
        let isTappable = viewModel.canOpenTaskDetail(task)
        let balloon: String? = viewModel.isOwnTask(task)
            ? String(localized: isKids ? "missions.trail.own_task_kids" : "missions.trail.own_task")
            : nil
        let row = HStack(alignment: .center, spacing: AppSpacing.base) {
            MissionTrailNodeView(appearance: MissionTrailNodeAppearance(task: task), size: Self.nodeSize)
                .overlay(alignment: .top) {
                    if let balloon {
                        MissionTrailBalloon(text: balloon)
                            .offset(y: -AppSpacing.xxl)
                    }
                }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(task.title)
                    .font(.app(isKids ? .bodyStrong : .subtitleStrong))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(MissionTrailText.secondaryLine(for: task))
                    .font(.app(isKids ? .noteStrong : .captionStrong))
                    .foregroundStyle(Color.App.Text.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, inset)
        .frame(minHeight: Self.nodeSize)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(MissionTrailText.accessibilityLabel(for: task, balloon: balloon)))

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

    // MARK: - Participations

    /// Figma "Quem já ajudou": avatars and the names joined (Admin/Membro only, CA-03).
    private func participationsBlock(_ participations: [MissionParticipation]) -> some View {
        let names = participations.map(\.displayName).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("missions.detail.participations_title")
                .font(.app(.noteStrong))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: -AppSpacing.sm) {
                    ForEach(participations) { participation in
                        MissionMemberAvatar(displayName: participation.displayName)
                    }
                }
                Text(names)
                    .font(.app(.bodyStrong))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .missionDetailCard()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(names))
        }
        .padding(.top, AppSpacing.sm)
        .accessibilityIdentifier("missions.detail.participations")
    }

    // MARK: - States

    /// UX-016 §6 `Loading`: header and block skeleton; nothing incomplete is interactive.
    private var skeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            Text(verbatim: "Placeholder mission title")
                .font(.app(.title2))
            Text(verbatim: "Placeholder status")
                .font(.app(.subtitleStrong))
            ProgressView(value: 0.5)
            ForEach(0 ..< 3, id: \.self) { _ in
                Text(verbatim: "Placeholder linked task")
                    .font(.app(.subtitleStrong))
            }
            Spacer()
        }
        .padding(AppSpacing.xxl)
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
}

private extension View {
    /// White card with the light chalk outline of Figma 907-14795 ("Observação", "Quem já ajudou").
    func missionDetailCard() -> some View {
        background(Color.App.Background.card, in: RoundedRectangle(cornerRadius: AppRadius.cardBoard))
            .chalkBorder(
                RoundedRectangle(cornerRadius: AppRadius.cardBoard).inset(by: 0.75),
                color: Color.App.Border.separator,
                lineWidth: 1.5,
                seed: 19
            )
    }
}
