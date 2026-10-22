import SwiftUI

/// Role-specific navigation shell. Task and mission content belongs to their own approved cards.
/// Adults reach Meu perfil (TEL-030) through the tab bar; Kids through the avatar button of each tab (no third tab).
struct AuthenticatedHomeView: View {
    let session: ActiveFamilySession
    @State private var profileViewModel: ProfileViewModel

    init(session: ActiveFamilySession, makeProfileViewModel: () -> ProfileViewModel) {
        self.session = session
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
                destination("destination.myTasks", icon: "checklist", identifier: "access.destination.adult")
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
}
