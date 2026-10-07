import SwiftUI

struct FoundationTabView: View {
    @State private var selection: FoundationTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(FoundationTab.allCases) { tab in
                FoundationTabContainer(tab: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
    }
}
