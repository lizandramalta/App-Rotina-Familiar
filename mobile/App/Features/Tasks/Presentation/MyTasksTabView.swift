import SwiftUI

/// Hosts the adult "Minhas tarefas" tab's `NavigationStack` (MA-09). Root content is TEL-010
/// (SCRUM-39): the stack pushes TEL-012/013 from there, same routes used since SCRUM-37.
struct MyTasksTabView: View {
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let familyRepository: any FamilyRepository
    let role: MemberRole
    let currentMemberID: UUID
    let accessToken: String

    @State private var path: [FamilyTaskRoute] = []
    @State private var listRevision = 0
    @State private var routineFeedback: Routine?
    @State private var isRefreshingRoutine = false
    @State private var routineRefreshFailed = false

    var body: some View {
        NavigationStack(path: $path) {
            DailyTaskListView(
                audience: .adult,
                repository: taskRepository,
                accessToken: accessToken,
                refreshRevision: listRevision,
                routineFeedback: routineFeedback,
                isRefreshingRoutine: isRefreshingRoutine,
                routineRefreshFailed: routineRefreshFailed,
                onSelectTask: { path.append(.detail($0)) },
                onCreateTask: { routineFeedback = nil; path.append(.create) },
                onRefreshRoutine: refreshRoutine
            )
            .accessibilityIdentifier("access.destination.adult")
            .navigationDestination(for: FamilyTaskRoute.self) { route in
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
    private func destination(for route: FamilyTaskRoute) -> some View {
        switch route {
        case .create:
            TaskEditorView(
                mode: .create,
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { _ in routineFeedback = nil; path.removeAll(); listRevision += 1 },
                onRoutineSaved: { routine in
                    routineFeedback = routine
                    routineRefreshFailed = false
                    path.removeAll()
                    listRevision += 1
                }
            )
        case let .detail(taskID):
            TaskDetailView(
                taskID: taskID,
                role: role,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                routineRepository: routineRepository,
                accessToken: accessToken,
                onRequestEdit: { path.append(.edit(taskID)) },
                onDeleted: { path.removeAll(); listRevision += 1 }
            )
        case let .edit(taskID):
            TaskEditorView(
                mode: .edit(taskID),
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { _ in if !path.isEmpty { path.removeLast() }; listRevision += 1 },
                onRoutineSaved: { _ in }
            )
        }
    }

    private func refreshRoutine() {
        guard let routineFeedback, !isRefreshingRoutine else { return }
        isRefreshingRoutine = true
        routineRefreshFailed = false
        Task {
            defer { isRefreshingRoutine = false }
            do {
                let latest = try await routineRepository.routine(id: routineFeedback.id, accessToken: accessToken)
                if self.routineFeedback?.id == latest.id {
                    self.routineFeedback = latest
                    listRevision += 1
                }
            } catch {
                routineRefreshFailed = true
            }
        }
    }

    #if DEBUG
    /// Lets `FamilyRoutineUITests` reach TEL-012/TEL-013 directly in a UI test scenario.
    private func seedPathForUITestsIfNeeded() {
        guard path.isEmpty, let seed = ProcessInfo.processInfo.environment["UI_TEST_TASK_ROUTE"] else {
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
