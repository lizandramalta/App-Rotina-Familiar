import SwiftUI

/// Narrower than `MissionRoute`: the Kids stack only ever pushes a mission detail and, from
/// there, a linked task's detail — never create/edit (mirrors `KidsTasksTabView`'s own plain
/// `[UUID]` stack, just disambiguating two destination kinds instead of one).
private enum KidsMissionRoute: Hashable {
    case detail(UUID)
    case taskDetail(UUID)
}

/// Hosts the Kids "Missões" tab's `NavigationStack` (SPEC-014 Fase 2, CA-19), mirroring
/// `KidsTasksTabView`. Owns its own `ProfileViewModel` instance rather than sharing
/// `AuthenticatedHomeView`'s: SwiftUI resolves a `.toolbar` against the nearest ancestor
/// `NavigationStack`, so the profile button must be attached inside this view's own stack.
struct KidsMissionsTabView: View {
    let missionRepository: any MissionRepository
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let currentMemberID: UUID
    let accessToken: String
    let makeProfileViewModel: () -> ProfileViewModel

    @State private var path: [KidsMissionRoute] = []
    @State private var profileViewModel: ProfileViewModel

    init(
        missionRepository: any MissionRepository,
        taskRepository: any TaskRepository,
        routineRepository: any RoutineRepository,
        currentMemberID: UUID,
        accessToken: String,
        makeProfileViewModel: @escaping () -> ProfileViewModel
    ) {
        self.missionRepository = missionRepository
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.currentMemberID = currentMemberID
        self.accessToken = accessToken
        self.makeProfileViewModel = makeProfileViewModel
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            MissionListView(
                repository: missionRepository,
                role: .kid,
                accessToken: accessToken,
                onSelectMission: { path.append(.detail($0)) },
                onCreateMission: {}
            )
            .accessibilityIdentifier("access.destination.kids.missions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .navigationDestination(for: KidsMissionRoute.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: KidsMissionRoute) -> some View {
        switch route {
        case let .detail(missionID):
            MissionDetailView(
                missionID: missionID,
                role: .kid,
                currentMemberID: currentMemberID,
                repository: missionRepository,
                taskRepository: taskRepository,
                accessToken: accessToken,
                onRequestEdit: {},
                onSelectTask: { path.append(.taskDetail($0)) }
            )
        case let .taskDetail(taskID):
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
