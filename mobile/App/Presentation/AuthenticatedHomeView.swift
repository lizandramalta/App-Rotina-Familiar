import SwiftUI

/// Role-specific navigation shell. Mission content belongs to its own approved card.
/// The adult "Minhas tarefas" tab hosts TEL-012/TEL-013 (SCRUM-37); its root list (TEL-010) is
/// still the placeholder below, reserved for the card that builds it.
/// Adults reach Meu perfil (TEL-030) through the tab bar; Kids through the avatar button of each tab (no third tab).
struct AuthenticatedHomeView: View {
    let session: ActiveFamilySession
    /// `nil` only if the session has no access token while authenticated, which should not happen;
    /// falls back to the plain placeholder rather than crashing.
    let myTasksTab: MyTasksTabView?
    let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?
    @State private var profileViewModel: ProfileViewModel

    init(
        session: ActiveFamilySession,
        myTasksTab: MyTasksTabView?,
        makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)? = nil,
        makeProfileViewModel: () -> ProfileViewModel
    ) {
        self.session = session
        self.myTasksTab = myTasksTab
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
        _profileViewModel = State(initialValue: makeProfileViewModel())
    }

    private var role: MemberRole { session.role }

    var body: some View {
        TabView {
            if role == .kid {
                destination("destination.myTasks", icon: "checklist", identifier: "access.destination.kids", showsProfileButton: true)
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
                familyDestination()
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
            }
        }
    }

    private func familyDestination() -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label("destination.family", systemImage: "person.3")
            } description: {
                Text("destination.contentPending")
            }
            .navigationTitle("destination.family")
            .accessibilityIdentifier("access.destination.family")
            .toolbar {
                if role == .administrator, let makeFamilySettingsViewModel {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            FamilySettingsView(viewModel: makeFamilySettingsViewModel())
                        } label: {
                            Image(systemName: "gearshape")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("family.settings.title")
                        .accessibilityIdentifier("family.navigation.settings_button")
                    }
                }
            }
        }
    }
}
