import SwiftUI

/// TEL-020 — Missões e conquistas (SPEC-016 Fase 2 / UX-016 §5.1): seções em andamento/concluídas,
/// cartões com estado, progresso canônico e situação da recompensa; atualização e falhas recuperáveis.
struct MissionListView: View {
    @State private var viewModel: MissionListViewModel
    let refreshRevision: Int
    let onSelectMission: (UUID) -> Void
    let onCreateMission: () -> Void
    let onOpenRewardItems: () -> Void

    init(
        repository: any MissionRepository,
        role: MemberRole,
        accessToken: String,
        refreshRevision: Int = 0,
        onSelectMission: @escaping (UUID) -> Void,
        onCreateMission: @escaping () -> Void,
        onOpenRewardItems: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: MissionListViewModel(repository: repository, role: role, accessToken: accessToken))
        self.refreshRevision = refreshRevision
        self.onSelectMission = onSelectMission
        self.onCreateMission = onCreateMission
        self.onOpenRewardItems = onOpenRewardItems
    }

    private var isKidsPresentation: Bool {
        viewModel.role == .kid
    }

    var body: some View {
        Group {
            if viewModel.showsSkeleton {
                skeleton
            } else if viewModel.loadFailed, viewModel.isEmpty {
                failureState
            } else {
                content
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("missions.list.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The hero carries the visible title (Figma 579-59); the nav bar keeps the title only
            // for VoiceOver and the back button of pushed screens.
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
            if viewModel.canCreate {
                // TEL-023 (SPEC-015 Fase 1) — Administrador apenas (CA-05); Membro/Kids nunca veem este atalho.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onOpenRewardItems()
                    } label: {
                        Image(systemName: "gift")
                    }
                    .accessibilityIdentifier("missions.list.reward_items")
                    .accessibilityLabel(Text("rewards.items.title"))
                }
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
        // Reloads on first appearance and whenever the host bumps `refreshRevision` (return from
        // TEL-021/022, after a save) — MA-15: refresh on open/return/after changes.
        .task(id: refreshRevision) {
            await viewModel.load()
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.refreshFailed {
                        MissionRefreshErrorBanner(
                            onRetry: { Task { await viewModel.load() } },
                            onDismiss: { viewModel.dismissRefreshError() }
                        )
                    }
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        section(title: "missions.section.in_progress", missions: viewModel.inProgress)
                        section(title: "missions.section.completed", missions: viewModel.completed)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground))
            }
        }
        // The hero's gray continues under the status/navigation bar, as in Figma 579-59.
        .background(alignment: .top) {
            Color(.systemGray5)
                .frame(height: 320)
                .ignoresSafeArea(edges: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        // UX-016 §6 `Refreshing`: native indicator while confirmed cards stay visible.
        .refreshable {
            await viewModel.load()
        }
        .accessibilityIdentifier("missions.list")
    }

    /// Figma "Hero · Missões da família": title, collective summary and placeholder illustration.
    private var hero: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("missions.hero.title")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle = viewModel.heroSubtitle {
                    Text(subtitle)
                        .font(isKidsPresentation ? .subheadline.weight(.medium) : .footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            // Placeholder illustration, as marked in Figma ("Ilustração · família (placeholder)").
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(.systemGray2))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray5))
        .accessibilityIdentifier("missions.hero")
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, missions: [MissionSummary]) -> some View {
        if !missions.isEmpty {
            Text(title)
                .textCase(.uppercase)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            ForEach(missions) { mission in
                card(for: mission)
            }
        }
    }

    private func card(for mission: MissionSummary) -> some View {
        let rewardState = viewModel.rewardState(for: mission)
        return Button {
            onSelectMission(mission.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mission.title)
                            .font(isKidsPresentation ? .title3.weight(.bold) : .headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        MissionProgressBar(
                            completedTaskCount: mission.completedTaskCount,
                            taskCount: mission.taskCount,
                            progressPercent: mission.progressPercent,
                            height: isKidsPresentation ? 24 : 20
                        )
                    }
                    MissionChestView(state: viewModel.chestState(for: mission))
                }
                HStack(spacing: 8) {
                    Text(viewModel.footerText(for: mission))
                        .font(isKidsPresentation ? .subheadline : .footnote)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: isKidsPresentation ? 56 : 44, alignment: .leading)
            .contentShape(Rectangle())
            .missionCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel(for: mission, rewardState: rewardState)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("missions.list.row.\(mission.id.uuidString)")
    }

    /// Status in words, full progress with percent, then the footer (UX-016 §8: fraction and
    /// percent announced together, color never the only cue).
    private func accessibilityLabel(for mission: MissionSummary, rewardState: MissionRewardState) -> String {
        let progress = missionProgressAccessibilityText(
            completed: mission.completedTaskCount,
            total: mission.taskCount,
            progressPercent: mission.progressPercent
        )
        var parts = [mission.title, statusLabel(for: mission.status), progress]
        switch mission.status {
        case .inProgress:
            parts.append(missionTasksRemainingText(taskCount: mission.taskCount, completedTaskCount: mission.completedTaskCount))
        case .completed:
            parts.append(MissionRewardText.text(for: rewardState))
        }
        return parts.joined(separator: ", ")
    }

    /// UX-016 §6 `Loading`: card skeleton; content interaction is unavailable until confirmed.
    private var skeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "Placeholder mission title")
                            .font(.headline)
                        Capsule().fill(Color(.systemGray5)).frame(height: 20)
                        Text(verbatim: "Placeholder footer")
                            .font(.footnote)
                    }
                    .padding(18)
                    .missionCard()
                }
            }
            .padding(20)
        }
        .redacted(reason: .placeholder)
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("missions.list.loading"))
        .accessibilityIdentifier("missions.list.loading")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("missions.list.empty_title", systemImage: "flag")
        } description: {
            // UX-016 §7: the creation hint is for Administrador only.
            if viewModel.canCreate {
                Text("missions.list.empty_description")
            }
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

    private func statusLabel(for status: MissionStatus) -> String {
        switch status {
        case .inProgress: String(localized: "missions.status.in_progress")
        case .completed: String(localized: "missions.status.completed")
        }
    }
}
