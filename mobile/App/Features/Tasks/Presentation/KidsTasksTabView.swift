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
    let familyRepository: (any FamilyRepository)?
    let currentMemberID: UUID
    let accessToken: String
    let recognition: RecognitionFeature?
    let makeProfileViewModel: () -> ProfileViewModel

    /// Task details and TEL-052 (SCRUM-103: destaque Kids is a destination, never a third tab).
    @State private var path: [FamilyTaskRoute] = []
    @State private var recognitionEntry: WeeklyRecognitionEntryViewModel?
    @State private var listRevision = 0
    @State private var profileViewModel: ProfileViewModel

    init(
        taskRepository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: (any FamilyRepository)? = nil,
        currentMemberID: UUID,
        accessToken: String,
        recognition: RecognitionFeature? = nil,
        makeProfileViewModel: @escaping () -> ProfileViewModel
    ) {
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.familyRepository = familyRepository
        self.currentMemberID = currentMemberID
        self.accessToken = accessToken
        self.recognition = recognition
        _recognitionEntry = State(initialValue: recognition?.makeEntryViewModel())
        self.makeProfileViewModel = makeProfileViewModel
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            DailyTaskListView(
                audience: .kid,
                role: .kid,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                refreshRevision: listRevision,
                onSelectTask: { path.append(.detail($0)) },
                onCreateTask: {},
                recognitionEntry: recognitionEntry,
                onOpenRecognition: { path.append(.weeklyRecognition($0)) }
            )
            .accessibilityIdentifier("access.destination.kids")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .navigationDestination(for: FamilyTaskRoute.self) { route in
                destination(for: route)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .onChange(of: recognition?.notificationRouter.pendingRecognitionID, initial: true) { _, pending in
            guard pending != nil, let id = recognition?.notificationRouter.consume() else { return }
            path = [.weeklyRecognition(id)]
        }
    }

    @ViewBuilder
    private func destination(for route: FamilyTaskRoute) -> some View {
        switch route {
        case let .detail(taskID):
            TaskDetailView(
                taskID: taskID,
                role: .kid,
                currentMemberID: currentMemberID,
                repository: taskRepository,
                routineRepository: routineRepository,
                accessToken: accessToken,
                onRequestEdit: { _ in },
                onDeleted: { path.removeAll(); listRevision += 1 },
                onReopened: { listRevision += 1 }
            )
        case let .weeklyRecognition(recognitionID):
            if let recognition {
                WeeklyRecognitionView(
                    viewModel: recognition.makeViewModel(recognitionID: recognitionID, audience: .kid)
                )
            }
        case .create, .edit:
            EmptyView()
        }
    }

    private var profileButton: some View {
        NavigationLink {
            // Pushed here (root of the adult Profile tab only), so the tab bar hides.
            ProfileView(viewModel: profileViewModel)
                .toolbar(.hidden, for: .tabBar)
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .frame(minWidth: 56, minHeight: 56)
        }
        .accessibilityLabel("kids.home.profile_button")
        .accessibilityIdentifier("kids.home.profile_button")
    }
}
