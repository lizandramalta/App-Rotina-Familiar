import Foundation
import Observation

/// Backs TEL-021 (SPEC-016 Fase 2 / UX-016 §5.2): canonical header, note, progress, linked tasks,
/// reward situation and — Administrador/Membro only — participations. Confirmed content survives a
/// failed refresh (CA-07); nothing is shown as changed until the server confirms it.
@MainActor
@Observable
final class MissionDetailViewModel {
    private let missionID: UUID
    let role: MemberRole
    private let currentMemberID: UUID
    private let getMissionDetail: GetMissionDetailUseCase
    private let hydrateLinkedTasks: HydrateLinkedTasksUseCase
    private let accessToken: String

    private(set) var mission: MissionDetail?
    private(set) var isLoading = false
    /// Initial load failed with no confirmed content (full-screen error).
    private(set) var loadFailed = false
    /// A refresh failed while the last confirmed detail stays visible (non-blocking banner).
    private(set) var refreshFailed = false
    /// Ids of linked tasks assigned to the current member. The detail projection carries no
    /// assignees, so ownership is resolved via the single-task lookup (decisão E-1). It drives the
    /// "SUA TAREFA"/"SUA VEZ!" balloon for everyone and, for Kids, which rows open TEL-041. If the
    /// lookup fails the set stays empty: no balloon, Kids rows non-tappable, adults unaffected.
    private(set) var ownTaskIDs: Set<UUID> = []

    private var loadGeneration = 0

    init(
        missionID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        accessToken: String
    ) {
        self.missionID = missionID
        self.role = role
        self.currentMemberID = currentMemberID
        self.getMissionDetail = GetMissionDetailUseCase(repository: repository)
        self.hydrateLinkedTasks = HydrateLinkedTasksUseCase(taskRepository: taskRepository)
        self.accessToken = accessToken
    }

    /// Admin only, and only enquanto a missão está em andamento (UX-014 §5.4).
    var canEdit: Bool {
        role == .administrator && mission?.status == .inProgress
    }

    /// SPEC-017 CA-08/UX-CA-01: only Administrador, only a completed mission the server reports as
    /// redeemable. Membro/Kids get no disabled button nor alternative route.
    var canRedeem: Bool {
        guard role == .administrator, let mission else { return false }
        return mission.status == .completed && mission.isRedemptionAvailable == true && mission.acceptedReward == nil
    }

    var rewardState: MissionRewardState? {
        guard let mission else { return nil }
        return MissionRewardState(acceptedReward: mission.acceptedReward, isRedemptionAvailable: mission.isRedemptionAvailable)
    }

    /// Participations are shown to Administrador/Membro only (CA-03, UX-016 §5.2). Kids never get
    /// the block nor a substitute count — even if a payload unexpectedly carried the field.
    var participations: [MissionParticipation]? {
        guard role != .kid, let mission, mission.status == .completed else { return nil }
        guard let participations = mission.participations, !participations.isEmpty else { return nil }
        return participations
    }

    /// Adults open any linked task (TEL-012). Kids only open their own (TEL-041); a task from
    /// someone else never becomes an operational path (UX-016 §5.2).
    func canOpenTaskDetail(_ task: MissionLinkedTask) -> Bool {
        guard role == .kid else { return true }
        return ownTaskIDs.contains(task.id)
    }

    func isOwnTask(_ task: MissionLinkedTask) -> Bool {
        ownTaskIDs.contains(task.id)
    }

    var chestState: MissionChestState? {
        guard let mission, let rewardState else { return nil }
        return MissionChestState(status: mission.status, rewardState: rewardState)
    }

    /// Banner subtitle (Figma 579-59): "N tarefas para abrir o baú" or "Missão concluída!".
    var bannerSubtitle: String? {
        guard let mission else { return nil }
        switch mission.status {
        case .completed:
            return String(localized: "mission.banner.completed")
        case .inProgress:
            let remaining = max(mission.tasks.count - mission.completedTaskCount, 0)
            return missionBannerRemainingText(remaining: remaining)
        }
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        let detail: MissionDetail
        do {
            detail = try await getMissionDetail.execute(missionID: missionID, accessToken: accessToken)
        } catch {
            guard generation == loadGeneration else { return }
            // Keeps the last confirmed detail; never claims a remote change (CA-07).
            if mission == nil {
                loadFailed = true
            } else {
                refreshFailed = true
            }
            return
        }

        let ownTaskIDs = await resolveOwnTaskIDs(in: detail)
        guard generation == loadGeneration else { return }
        self.mission = detail
        self.ownTaskIDs = ownTaskIDs
        loadFailed = false
        refreshFailed = false
    }

    func dismissRefreshError() {
        refreshFailed = false
    }

    private func resolveOwnTaskIDs(in detail: MissionDetail) async -> Set<UUID> {
        do {
            // A linked task the actor cannot read is simply not theirs (SPEC-011 CA-10).
            let tasks = try await hydrateLinkedTasks.execute(
                taskIDs: detail.tasks.map(\.id),
                accessToken: accessToken,
                skippingUnavailable: true
            )
            return Set(tasks.filter { $0.assigneeIDs.contains(currentMemberID) }.map(\.id))
        } catch {
            // Conservative fallback (decisão E-1): content stays visible, rows become non-tappable.
            return []
        }
    }
}
