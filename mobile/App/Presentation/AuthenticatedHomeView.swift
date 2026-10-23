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
    let kidsTaskList: DailyTaskListView?
    @State private var profileViewModel: ProfileViewModel

    init(
        session: ActiveFamilySession,
        myTasksTab: MyTasksTabView?,
        kidsTaskList: DailyTaskListView?,
        makeProfileViewModel: () -> ProfileViewModel
    ) {
        self.session = session
        self.myTasksTab = myTasksTab
        self.kidsTaskList = kidsTaskList
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    private var role: MemberRole { session.role }

    var body: some View {
        TabView {
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
                destination("destination.family", icon: "person.3", identifier: "access.destination.family")
                    .tabItem { Label("destination.family", systemImage: "person.3") }
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
}
