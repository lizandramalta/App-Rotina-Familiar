import Foundation
import Observation

/// Backs TEL-020 (SPEC-016 Fase 2 / UX-016 §5.1): canonical "Em andamento"/"Concluídas" collections
/// with progress and reward state. Confirmed content is never discarded by a later failure (CA-07):
/// a failed refresh only raises a non-blocking banner and the cards stay as last confirmed.
@MainActor
@Observable
final class MissionListViewModel {
    private let listMissions: ListMissionsUseCase
    private let accessToken: String
    let role: MemberRole

    private(set) var inProgress: [MissionSummary] = []
    private(set) var completed: [MissionSummary] = []
    private(set) var isLoading = false
    /// `true` once a response has been confirmed — distinguishes "never loaded" from "empty".
    private(set) var hasLoaded = false
    /// Initial load failed and there is no confirmed content to show (full-screen error).
    private(set) var loadFailed = false
    /// A refresh failed while confirmed content stays visible (non-blocking banner).
    private(set) var refreshFailed = false

    /// Bumped on every load; a response is applied only if it is still the latest request, so an
    /// older, slower response never overwrites a newer one (mobile-code-conventions §4).
    private var loadGeneration = 0

    init(repository: any MissionRepository, role: MemberRole, accessToken: String) {
        self.listMissions = ListMissionsUseCase(repository: repository)
        self.role = role
        self.accessToken = accessToken
    }

    /// Only Administrador creates/edits missions (RN37) — Membro and Kids never see the action.
    var canCreate: Bool {
        role == .administrator
    }

    var isEmpty: Bool {
        inProgress.isEmpty && completed.isEmpty
    }

    /// Skeleton only before the first confirmed response; afterwards a load is a `Refreshing` state.
    var showsSkeleton: Bool {
        isLoading && !hasLoaded
    }

    /// Hero subtitle (Figma 579-59): adults get "N em andamento · M concluídas"; Kids get the
    /// collective "Vocês já concluíram M missões juntos!", hidden while M is 0 (no copy for it).
    var heroSubtitle: String? {
        guard hasLoaded else { return nil }
        if role == .kid {
            guard !completed.isEmpty else { return nil }
            return missionsHeroKidsSummaryText(completed: completed.count)
        }
        return missionsHeroSummaryText(inProgress: inProgress.count, completed: completed.count)
    }

    func chestState(for mission: MissionSummary) -> MissionChestState {
        MissionChestState(status: mission.status, rewardState: rewardState(for: mission))
    }

    /// Card footer: tasks still missing while in progress; the reward situation once completed.
    func footerText(for mission: MissionSummary) -> String {
        switch mission.status {
        case .inProgress:
            missionTasksRemainingText(taskCount: mission.taskCount, completedTaskCount: mission.completedTaskCount)
        case .completed:
            MissionRewardText.text(for: rewardState(for: mission))
        }
    }

    func rewardState(for mission: MissionSummary) -> MissionRewardState {
        MissionRewardState(acceptedReward: mission.acceptedReward, isRedemptionAvailable: mission.isRedemptionAvailable)
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

        do {
            let collections = try await listMissions.execute(accessToken: accessToken)
            guard generation == loadGeneration else { return }
            inProgress = collections.inProgress
            completed = collections.completed
            hasLoaded = true
            loadFailed = false
            refreshFailed = false
        } catch {
            guard generation == loadGeneration else { return }
            // Never claims a remote change: confirmed cards are kept untouched (CA-07).
            if hasLoaded {
                refreshFailed = true
            } else {
                loadFailed = true
            }
        }
    }

    func dismissRefreshError() {
        refreshFailed = false
    }
}
