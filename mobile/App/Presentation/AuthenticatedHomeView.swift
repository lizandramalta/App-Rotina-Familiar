import SwiftUI

/// Adult navigation for the first TestFlight release.
struct AuthenticatedHomeView: View {
    let session: ActiveFamilySession
    /// `nil` only if the session has no access token while authenticated, which should not happen;
    /// falls back to the plain placeholder rather than crashing.
    let myTasksTab: MyTasksTabView?
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var familyOverviewViewModel: FamilyOverviewViewModel
    @State private var familyTaskPath: [FamilyNavigationRoute] = []
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
        if scenario == "family-settings" || scenario == "family-overview" || scenario == "family-overview-incentives" || scenario == "family-overview-own-most-tasks" || scenario == "family-overview-member" || scenario == "family-tasks" || scenario == "member-invite" || scenario == "member-invite-uncertain" {
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
        makeProfileViewModel: () -> ProfileViewModel
    ) {
        self.session = session
        self.myTasksTab = myTasksTab
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
        _familyOverviewViewModel = State(initialValue: makeFamilyOverviewViewModel())
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .tint(Color.primary)
        .id(session.role)
    }

    private func destination(
        _ title: LocalizedStringKey,
        icon: String,
        identifier: String
    ) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text("destination.contentPending")
            }
            .navigationTitle(title)
            .accessibilityIdentifier(identifier)
        }
    }

    private func familyDestination() -> some View {
        NavigationStack(path: $familyTaskPath) {
            FamilyOverviewView(viewModel: familyOverviewViewModel)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("access.destination.family")
            .navigationDestination(for: FamilyNavigationRoute.self) { route in
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
    private func familyTaskDestination(_ route: FamilyNavigationRoute) -> some View {
        switch route {
        case let .member(memberID):
            MemberDetailView(
                viewModel: familyOverviewViewModel.makeMemberDetailViewModel(memberID: memberID),
                onOpenTask: { familyTaskPath.append(.detail($0)) },
                onRemoved: { Task { await familyOverviewViewModel.loadInitial() } },
                onUpdated: { Task { await familyOverviewViewModel.loadInitial() } }
            )
        case .familyTasks:
            if let tasks = familyOverviewViewModel.makeFamilyTasksViewModel() {
                FamilyTasksView(viewModel: tasks, onOpenTask: { familyTaskPath.append(.detail($0)) })
            }
        case .settingsHub:
            FamilySettingsHubView(
                viewModel: familyOverviewViewModel,
                makeFamilySettingsViewModel: makeFamilySettingsViewModel
            )
        case .create, .detail, .edit:
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
                    onRequestEdit: { scope in familyTaskPath.append(.edit(taskID, scope: scope)) },
                    onDeleted: {
                        familyTaskPath.removeAll()
                        Task { await familyOverviewViewModel.loadInitial() }
                    },
                    onCompleted: { Task { await familyOverviewViewModel.loadInitial() } },
                    onReopened: { Task { await familyOverviewViewModel.loadInitial() } }
                )
            case let .edit(taskID, scope):
                TaskEditorView(
                    mode: .edit(taskID, scope: scope),
                    repository: myTasksTab.taskRepository,
                    routineRepository: myTasksTab.routineRepository,
                    familyRepository: myTasksTab.familyRepository,
                    accessToken: myTasksTab.accessToken,
                    currentMemberID: session.memberID,
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
            case .member, .familyTasks, .settingsHub:
                EmptyView()
            }
            }
        }
    }
}
