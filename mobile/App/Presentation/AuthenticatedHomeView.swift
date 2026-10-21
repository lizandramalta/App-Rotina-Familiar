import SwiftUI

/// Role-specific navigation shell. Task and mission content belongs to their own approved cards.
struct AuthenticatedHomeView: View {
    let role: MemberRole

    var body: some View {
        TabView {
            if role == .kid {
                destination("destination.myTasks", icon: "checklist", identifier: "access.destination.kids")
                    .tabItem { Label("destination.myTasks", systemImage: "checklist") }
                destination("destination.missions", icon: "star", identifier: "access.destination.kids.missions")
                    .tabItem { Label("destination.missions", systemImage: "star") }
            } else {
                destination("destination.myTasks", icon: "checklist", identifier: "access.destination.adult")
                    .tabItem { Label("destination.myTasks", systemImage: "checklist") }
                destination("destination.family", icon: "person.3", identifier: "access.destination.family")
                    .tabItem { Label("destination.family", systemImage: "person.3") }
                destination("destination.missions", icon: "star", identifier: "access.destination.missions")
                    .tabItem { Label("destination.missions", systemImage: "star") }
                destination("destination.myProfile", icon: "person.crop.circle", identifier: "access.destination.profile")
                    .tabItem { Label("destination.myProfile", systemImage: "person.crop.circle") }
            }
        }
        .id(role)
    }

    private func destination(_ title: LocalizedStringKey, icon: String, identifier: String) -> some View {
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
}
