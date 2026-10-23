import SwiftUI

/// Hosts the adult "Minhas tarefas" tab's `NavigationStack` (MA-09). Root content is TEL-010
/// (SCRUM-39): the stack pushes TEL-012/013 from there, same routes used since SCRUM-37.
struct MyTasksTabView: View {
    let taskRepository: any TaskRepository
    let familyRepository: any FamilyRepository
    let accessToken: String

    @State private var path: [FamilyTaskRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            DailyTaskListView(
                audience: .adult,
                repository: taskRepository,
                accessToken: accessToken,
                onSelectTask: { path.append(.detail($0)) },
                onCreateTask: { path.append(.create) }
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
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { path.removeAll() }
            )
        case let .detail(taskID):
            TaskDetailView(
                taskID: taskID,
                repository: taskRepository,
                accessToken: accessToken,
                onRequestEdit: { path.append(.edit(taskID)) },
                onDeleted: { path.removeAll() }
            )
        case let .edit(taskID):
            TaskEditorView(
                mode: .edit(taskID),
                repository: taskRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onSaved: { if !path.isEmpty { path.removeLast() } }
            )
        }
    }

    #if DEBUG
    /// Lets `FamilyRoutineUITests` reach TEL-012/TEL-013 before any card builds the real list
    /// (TEL-010/TEL-011). Never active outside a `UI_TEST_SCENARIO` launch.
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
