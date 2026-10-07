import SwiftUI

struct FoundationPlaceholderView: View {
    let tab: FoundationTab
    let isDestination: Bool

    init(tab: FoundationTab, isDestination: Bool = false) {
        self.tab = tab
        self.isDestination = isDestination
    }

    var body: some View {
        ContentUnavailableView {
            Label(tab.title, systemImage: tab.systemImage)
        } description: {
            Text("foundation.placeholder.description")
        } actions: {
            if !isDestination {
                NavigationLink(value: tab.initialRoute) {
                    Text("foundation.placeholder.action")
                }
            }
        }
        .navigationTitle(tab.title)
    }
}
