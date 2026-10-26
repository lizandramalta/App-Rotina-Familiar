import SwiftUI

/// Hosts the adult "Missões" tab's `NavigationStack` (SPEC-014 Fase 2). Root is TEL-020; the
/// stack pushes TEL-021/022, MOD-007's host, and the shared `TaskDetailView`/`TaskEditorView`
/// for a linked task — same ownership pattern already used by `MyTasksTabView` (SCRUM-37).
struct MissionsTabView: View {
    let missionRepository: any MissionRepository
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let familyRepository: any FamilyRepository
    let role: MemberRole
    let currentMemberID: UUID
    let accessToken: String

    @State private var path: [MissionRoute] = []
    @State private var listRevision = 0

    var body: some View {
        NavigationStack(path: $path) {
            MissionListView(
                repository: missionRepository,
                role: role,
                accessToken: accessToken,
                refreshRevision: listRevision,
                onSelectMission: { path.append(.detail($0)) },
                onCreateMission: { path.append(.create) }
            )
            .accessibilityIdentifier("access.destination.missions")
            .navigationDestination(for: MissionRoute.self) { route in
                destination(for: route)
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
                onSaved: { path.removeAll(); listRevision += 1 }
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
                onSelectTask: { path.append(.taskDetail($0)) }
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
                accessToken: accessToken,
                onRequestEdit: { path.append(.taskEdit(taskID)) },
                onDeleted: { if !path.isEmpty { path.removeLast() } }
            )
        case let .taskEdit(taskID):
            TaskEditorView(
                mode: .edit(taskID),
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { _ in if !path.isEmpty { path.removeLast() } },
                onRoutineSaved: { _ in }
            )
        }
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
