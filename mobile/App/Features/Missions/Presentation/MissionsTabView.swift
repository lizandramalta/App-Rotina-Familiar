import SwiftUI

/// Hosts the adult "Missões" tab's `NavigationStack` (SPEC-014 Fase 2). Root is TEL-020; the
/// stack pushes TEL-021/022, MOD-007's host, and the shared `TaskDetailView`/`TaskEditorView`
/// for a linked task — same ownership pattern already used by `MyTasksTabView` (SCRUM-37).
struct MissionsTabView: View {
    let missionRepository: any MissionRepository
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let familyRepository: any FamilyRepository
    let rewardRepository: any RewardRepository
    let role: MemberRole
    let currentMemberID: UUID
    let accessToken: String

    @State private var path: [MissionRoute] = []
    @State private var listRevision = 0
    /// Reloads TEL-021 when TEL-024 returns, whatever the outcome (UX-017 §4).
    @State private var detailRevision = 0

    var body: some View {
        NavigationStack(path: $path) {
            MissionListView(
                repository: missionRepository,
                role: role,
                accessToken: accessToken,
                refreshRevision: listRevision,
                onSelectMission: { path.append(.detail($0)) },
                onCreateMission: { path.append(.create) },
                onOpenRewardItems: { path.append(.rewardItems) }
            )
            .accessibilityIdentifier("access.destination.missions")
            .navigationDestination(for: MissionRoute.self) { route in
                // Tab bar only on each tab's root route; every pushed screen hides it.
                destination(for: route)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        // MA-15 / UX-016 §4: returning to TEL-020 reloads the canonical list, so a card reflects
        // whatever TEL-021/022 confirmed (including saves, which pop back to the root too).
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty {
                listRevision += 1
            }
        }
        #if DEBUG
        .task {
            seedPathForUITestsIfNeeded()
        }
        #endif
    }

    @ViewBuilder
    private func destination(for route: MissionRoute) -> some View {
        switch route {
        case .create:
            MissionEditorView(
                mode: .create,
                repository: missionRepository,
                taskRepository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { path.removeAll() }
            )
        case let .detail(missionID):
            MissionDetailView(
                missionID: missionID,
                role: role,
                currentMemberID: currentMemberID,
                repository: missionRepository,
                taskRepository: taskRepository,
                accessToken: accessToken,
                onRequestEdit: { path.append(.edit(missionID)) },
                onSelectTask: { path.append(.taskDetail($0)) },
                onRedeem: { mission in path.append(.rewardWheel(mission.id, missionTitle: mission.title)) },
                refreshRevision: detailRevision
            )
        case let .edit(missionID):
            MissionEditorView(
                mode: .edit(missionID),
                repository: missionRepository,
                taskRepository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { if !path.isEmpty { path.removeLast() }; listRevision += 1 }
            )
        case let .taskDetail(taskID):
            TaskDetailView(
                taskID: taskID,
                role: role,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onRequestEdit: { scope in path.append(.taskEdit(taskID, scope: scope)) },
                onDeleted: { if !path.isEmpty { path.removeLast() } }
            )
        case .rewardItems:
            RewardItemsView(
                repository: rewardRepository,
                role: role,
                accessToken: accessToken
            )
        case let .rewardWheel(missionID, missionTitle):
            RewardWheelView(
                viewModel: RewardWheelViewModel(
                    missionID: missionID,
                    missionTitle: missionTitle,
                    missionRepository: missionRepository,
                    rewardRepository: rewardRepository,
                    accessToken: accessToken
                ),
                onAccepted: { _ in returnToMissionDetail() },
                onLeave: { returnToMissionDetail() },
                onOpenCatalog: { path.append(.rewardItemsConsult) }
            )
        case .rewardItemsConsult:
            RewardItemsView(
                repository: rewardRepository,
                role: role,
                accessToken: accessToken,
                allowsManagement: false
            )
        case let .taskEdit(taskID, scope):
            TaskEditorView(
                mode: .edit(taskID, scope: scope),
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                currentMemberID: currentMemberID,
                onSaved: { _ in if !path.isEmpty { path.removeLast() } },
                onRoutineSaved: { _ in }
            )
        }
    }

    /// Pops TEL-024 (and a consult TEL-023 above it) back to TEL-021 and reloads it.
    private func returnToMissionDetail() {
        if let wheel = path.lastIndex(where: { if case .rewardWheel = $0 { true } else { false } }) {
            path.removeSubrange(wheel...)
        }
        detailRevision += 1
    }

    #if DEBUG
    /// Lets `FamilyRoutineUITests` reach TEL-021/022 directly in a UI test scenario.
    private func seedPathForUITestsIfNeeded() {
        guard path.isEmpty, let seed = ProcessInfo.processInfo.environment["UI_TEST_MISSION_ROUTE"] else {
            return
        }
        if seed == "create" {
            path = [.create]
        } else if seed.hasPrefix("detail:"), let id = UUID(uuidString: String(seed.dropFirst("detail:".count))) {
            path = [.detail(id)]
        }
    }
    #endif
}
