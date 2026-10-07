import SwiftUI

struct FoundationTabContainer: View {
    let tab: FoundationTab
    @State private var path: [FoundationRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            FoundationPlaceholderView(tab: tab)
                .navigationDestination(for: FoundationRoute.self) { route in
                    FoundationRouteDestinationView(route: route)
                }
        }
    }
}

private struct FoundationRouteDestinationView: View {
    let route: FoundationRoute

    var body: some View {
        switch route {
        case let .placeholder(tab):
            FoundationPlaceholderView(tab: tab, isDestination: true)
        }
    }
}
