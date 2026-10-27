import SwiftUI

/// Role-specific navigation shell. Mission content belongs to its own approved card.
/// The adult "Minhas tarefas" tab hosts TEL-010/TEL-012/TEL-013 (SCRUM-37/39); the Kids tab
/// hosts TEL-040 (SCRUM-39), its own own-daily checklist, no family navigation (CA-04).
/// Adults reach Meu perfil (TEL-030) through the tab bar; Kids through the avatar button of each tab (no third tab).
struct AuthenticatedHomeView: View {
    let session: ActiveFamilySession
    /// `nil` only if the session has no access token while authenticated, which should not happen;
    /// falls back to the plain placeholder rather than crashing.
    let myTasksTab: MyTasksTabView?
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var familyOverviewViewModel: FamilyOverviewViewModel
    @State private var familyTaskPath: [FamilyTaskRoute] = []
    let kidsTasksTabView: KidsTasksTabView?
    let missionsTab: MissionsTabView?
    let kidsMissionsTabView: KidsMissionsTabView?
    @State private var profileViewModel: ProfileViewModel
    @State private var showsFamilySettingsScenario: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"] == "family-settings"
        #else
        return false
        #endif
    }()
    @State private var selectedTab: Int = {
        #if DEBUG
        let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]
        if scenario == "family-settings" || scenario == "family-overview" || scenario == "family-overview-member" || scenario == "member-invite" || scenario == "member-invite-uncertain" || scenario == "kids-review-queue" || scenario == "kids-review-queue-empty" || scenario == "kids-review-queue-failure" {
            return 1
        }
        if scenario == "mission-management" || scenario == "mission-management-member" {
            return 2
        }
        if scenario == "mission-management-kids" {
            return 1
        }
        #endif
        return 0
    }()

    init(
        session: ActiveFamilySession,
        myTasksTab: MyTasksTabView?,
        makeFamilyOverviewViewModel: () -> FamilyOverviewViewModel,
        makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)? = nil,
        kidsTasksTabView: KidsTasksTabView?,
        missionsTab: MissionsTabView?,
        kidsMissionsTabView: KidsMissionsTabView?,
        makeProfileViewModel: () -> ProfileViewModel
    ) {
        self.session = session
        self.myTasksTab = myTasksTab
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
        self.kidsTasksTabView = kidsTasksTabView
        self.missionsTab = missionsTab
        self.kidsMissionsTabView = kidsMissionsTabView
        _familyOverviewViewModel = State(initialValue: makeFamilyOverviewViewModel())
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    private var role: MemberRole { session.role }

    var body: some View {
        TabView(selection: $selectedTab) {
            if role == .kid {
                Group {
                    if let kidsTasksTabView {
                        kidsTasksTabView
                    } else {
                        destination("destination.myTasks", icon: "checklist", identifier: "access.destination.kids", showsProfileButton: true)
                    }
                }
                .tabItem {
                    Label {
                        Text("destination.myTasks")
                    } icon: {
                        Image(systemName: "checklist")
                    }
                }
                .tag(0)
                Group {
                    if let kidsMissionsTabView {
                        kidsMissionsTabView
                    } else {
                        destination("destination.missions", icon: "star", identifier: "access.destination.kids.missions", showsProfileButton: true)
                    }
                }
                .tabItem {
                    Label {
                        Text("destination.missions")
                    } icon: {
                        Image(systemName: "flag")
                    }
                }
                .tag(1)
            } else {
                Group {
                    if let myTasksTab {
                        myTasksTab
                    } else {
                        destination("destination.myTasks", icon: "checklist", identifier: "access.destination.adult")
                    }
                }
                .tabItem {
                    Label {
                        Text("tasks.adult.title")
                    } icon: {
                        Image(systemName: "checklist")
                    }
                }
                .tag(0)
                familyDestination()
                    .tabItem {
                        Label {
                            Text("destination.family")
                        } icon: {
                            Image(systemName: "person.2")
                        }
                    }
                    .tag(1)
                Group {
                    if let missionsTab {
                        missionsTab
                    } else {
                        destination("destination.missions", icon: "star", identifier: "access.destination.missions")
                    }
                }
                .tabItem {
                    Label {
                        Text("tasks.adult.missionsTab")
                    } icon: {
                        Image(systemName: "flag")
                    }
                }
                .tag(2)
                NavigationStack {
                    ProfileView(viewModel: profileViewModel)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("access.destination.profile")
                }
                .tabItem {
                    Label {
                        Text("tasks.adult.profileTab")
                    } icon: {
                        Image(systemName: "person")
                    }
                }
            }
        }
        .id(role)
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

    private func destination(
        _ title: LocalizedStringKey,
        icon: String,
        identifier: String,
        showsProfileButton: Bool = false
    ) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text("destination.contentPending")
            }
            .navigationTitle(title)
            .accessibilityIdentifier(identifier)
            .toolbar {
                if showsProfileButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        profileButton
                    }
                }
            }
        }
    }

    private func familyDestination() -> some View {
        NavigationStack(path: $familyTaskPath) {
            FamilyOverviewView(
                viewModel: familyOverviewViewModel,
                makeFamilySettingsViewModel: makeFamilySettingsViewModel
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("access.destination.family")
            .navigationDestination(for: FamilyTaskRoute.self) { route in
                familyTaskDestination(route)
            }
            .navigationDestination(isPresented: $showsFamilySettingsScenario) {
                if let makeFamilySettingsViewModel {
                    FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                }
            }
        }
    }

    @ViewBuilder
    private func familyTaskDestination(_ route: FamilyTaskRoute) -> some View {
        if let myTasksTab {
            switch route {
            case let .detail(taskID):
                TaskDetailView(
                    taskID: taskID,
                    role: session.role,
                    currentMemberID: session.memberID,
                    repository: myTasksTab.taskRepository,
                    routineRepository: myTasksTab.routineRepository,
                    familyRepository: myTasksTab.familyRepository,
                    accessToken: myTasksTab.accessToken,
                    onRequestEdit: { familyTaskPath.append(.edit(taskID)) },
                    onDeleted: {
                        familyTaskPath.removeAll()
                        Task { await familyOverviewViewModel.loadInitial() }
                    },
                    onCompleted: { Task { await familyOverviewViewModel.loadInitial() } },
                    onReopened: { Task { await familyOverviewViewModel.loadInitial() } }
                )
            case let .edit(taskID):
                TaskEditorView(
                    mode: .edit(taskID),
                    repository: myTasksTab.taskRepository,
                    routineRepository: myTasksTab.routineRepository,
                    familyRepository: myTasksTab.familyRepository,
                    accessToken: myTasksTab.accessToken,
                    onSaved: { _ in
                        if !familyTaskPath.isEmpty { familyTaskPath.removeLast() }
                        Task { await familyOverviewViewModel.loadInitial() }
                    },
                    onRoutineSaved: { _ in }
                )
            case .create:
                TaskEditorView(
                    mode: .create,
                    repository: myTasksTab.taskRepository,
                    routineRepository: myTasksTab.routineRepository,
                    familyRepository: myTasksTab.familyRepository,
                    accessToken: myTasksTab.accessToken,
                    onSaved: { _ in
                        familyTaskPath.removeAll()
                        Task { await familyOverviewViewModel.loadInitial() }
                    },
                    onRoutineSaved: { _ in }
                )
            }
        }
    }
}
