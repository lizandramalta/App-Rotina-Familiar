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
    let accessTokenProvider: AccessTokenProvider

    @State private var path: [FamilyTaskRoute] = []
    @State private var listRevision = 0
    @State private var showsSavedToast = false

    var body: some View {
        NavigationStack(path: $path) {
            DailyTaskListView(
                audience: .adult,
                role: role,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                familyRepository: familyRepository,
                accessTokenProvider: accessTokenProvider,
                refreshRevision: listRevision,
                onSelectTask: { path.append(.detail($0)) },
                onCreateTask: { path.append(.create) }
            )
            .accessibilityIdentifier("access.destination.adult")
            .navigationDestination(for: FamilyTaskRoute.self) { route in
                destination(for: route)
            }
        }
        .overlay {
            if showsSavedToast { savedToast }
        }
        .animation(.spring(duration: 0.3), value: showsSavedToast)
        .task(id: showsSavedToast) {
            guard showsSavedToast else { return }
            try? await Task.sleep(for: .seconds(2))
            showsSavedToast = false
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
                currentMemberID: currentMemberID,
                onSaved: { _ in finishCreation() },
                onRoutineSaved: { _ in finishCreation() }
            )
        case let .detail(taskID):
            TaskDetailView(
                taskID: taskID,
                role: role,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                onRequestEdit: { scope in path.append(.edit(taskID, scope: scope)) },
                onDeleted: { path.removeAll(); listRevision += 1 },
                onCompleted: { listRevision += 1 },
                onReopened: { listRevision += 1 }
            )
        case let .edit(taskID, scope):
            TaskEditorView(
                mode: .edit(taskID, scope: scope),
                repository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                currentMemberID: currentMemberID,
                onSaved: { _ in if !path.isEmpty { path.removeLast() }; listRevision += 1 },
                onRoutineSaved: { _ in }
            )
        }
    }

    private func finishCreation() {
        path.removeAll()
        listRevision += 1
        showsSavedToast = true
    }

    /// Transient confirmation after creating a task or routine; disappears on its own.
    private var savedToast: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("tasks.saved.toast")
                .font(.headline)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tasks.saved.toast")
        .accessibilityAddTraits(.isStaticText)
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
