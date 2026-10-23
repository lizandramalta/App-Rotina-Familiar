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
    let kidsTaskList: DailyTaskListView?
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
        if scenario == "family-settings" || scenario == "family-overview" || scenario == "family-overview-member" {
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
        kidsTaskList: DailyTaskListView?,
        makeProfileViewModel: () -> ProfileViewModel
    ) {
        self.session = session
        self.myTasksTab = myTasksTab
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
        self.kidsTaskList = kidsTaskList
        _familyOverviewViewModel = State(initialValue: makeFamilyOverviewViewModel())
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    private var role: MemberRole { session.role }

    var body: some View {
        TabView(selection: $selectedTab) {
            if role == .kid {
                Group {
                    if let kidsTaskList {
                        NavigationStack {
                            kidsTaskList
                                .accessibilityIdentifier("access.destination.kids")
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        profileButton
                                    }
                                }
                        }
                    } else {
                        destination("destination.myTasks", icon: "checklist", identifier: "access.destination.kids", showsProfileButton: true)
                    }
                }
                .tabItem { Label("destination.myTasks", systemImage: "checklist") }
                destination("destination.missions", icon: "star", identifier: "access.destination.kids.missions", showsProfileButton: true)
                    .tabItem { Label("destination.missions", systemImage: "star") }
            } else {
                Group {
                    if let myTasksTab {
                        myTasksTab
                    } else {
                        destination("destination.myTasks", icon: "checklist", identifier: "access.destination.adult")
                    }
                }
                .tabItem { Label("destination.myTasks", systemImage: "checklist") }
                .tag(0)
                familyDestination()
                    .tabItem { Label("destination.family", systemImage: "person.3") }
                    .tag(1)
                destination("destination.missions", icon: "star", identifier: "access.destination.missions")
                    .tabItem { Label("destination.missions", systemImage: "star") }
                NavigationStack {
                    ProfileView(viewModel: profileViewModel)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("access.destination.profile")
                }
                .tabItem { Label("destination.myProfile", systemImage: "person.crop.circle") }
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
        NavigationStack {
            FamilyOverviewView(
                viewModel: familyOverviewViewModel,
                makeFamilySettingsViewModel: makeFamilySettingsViewModel
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("access.destination.family")
            .navigationDestination(isPresented: $showsFamilySettingsScenario) {
                if let makeFamilySettingsViewModel {
                    FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                }
            }
        }
    }
}
