import SwiftUI

/// Hosts the Kids "Minhas tarefas" tab's `NavigationStack` (MA-09), mirroring `MyTasksTabView`.
/// Added by SPEC-011: Kids must reach their own completed task (TEL-012) to reopen it, which
/// UX-009's original Kids placeholder (informational-only rows) didn't anticipate.
///
/// Owns its own `ProfileViewModel` instance (built via `makeProfileViewModel`) rather than sharing
/// `AuthenticatedHomeView`'s: SwiftUI resolves a `.toolbar` against the nearest ANCESTOR
/// `NavigationStack`, so the profile button must be attached inside this view's own stack, not
/// wrapped around it from the caller.
struct KidsTasksTabView: View {
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let currentMemberID: UUID
    let accessToken: String
    let makeProfileViewModel: () -> ProfileViewModel

    @State private var path: [UUID] = []
    @State private var profileViewModel: ProfileViewModel

    init(
        taskRepository: any TaskRepository,
        routineRepository: any RoutineRepository,
        currentMemberID: UUID,
        accessToken: String,
        makeProfileViewModel: @escaping () -> ProfileViewModel
    ) {
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.currentMemberID = currentMemberID
        self.accessToken = accessToken
        self.makeProfileViewModel = makeProfileViewModel
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            DailyTaskListView(
                audience: .kid,
                repository: taskRepository,
                accessToken: accessToken,
                onSelectTask: { path.append($0) },
                onCreateTask: {}
            )
            .accessibilityIdentifier("access.destination.kids")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .navigationDestination(for: UUID.self) { taskID in
                TaskDetailView(
                    taskID: taskID,
                    role: .kid,
                    currentMemberID: currentMemberID,
                    repository: taskRepository,
                    routineRepository: routineRepository,
                    accessToken: accessToken,
                    onRequestEdit: {},
                    onDeleted: { path.removeAll() }
                )
            }
        }
    }

    private var profileButton: some View {
        NavigationLink {
            ProfileView(viewModel: profileViewModel)
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .frame(minWidth: 56, minHeight: 56)
        }
        .accessibilityLabel("kids.home.profile_button")
        .accessibilityIdentifier("kids.home.profile_button")
    }
}
