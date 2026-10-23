import SwiftUI

/// Role-specific navigation shell. Mission content belongs to its own approved card.
/// The adult "Minhas tarefas" tab hosts TEL-010/TEL-012/TEL-013 (SCRUM-37/39); the Kids tab
/// hosts TEL-040 (SCRUM-39), its own own-daily checklist, no family navigation (CA-04).
struct AuthenticatedHomeView: View {
    let role: MemberRole
    /// `nil` only if the session has no access token while authenticated, which should not happen;
    /// falls back to the plain placeholder rather than crashing.
    let myTasksTab: MyTasksTabView?
    let kidsTaskList: DailyTaskListView?

    var body: some View {
        TabView {
            if role == .kid {
                Group {
                    if let kidsTaskList {
                        NavigationStack {
                            kidsTaskList
                                .accessibilityIdentifier("access.destination.kids")
                        }
                    } else {
                        destination("destination.myTasks", icon: "checklist", identifier: "access.destination.kids")
                    }
                }
                .tabItem { Label("destination.myTasks", systemImage: "checklist") }
                destination("destination.missions", icon: "star", identifier: "access.destination.kids.missions")
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
