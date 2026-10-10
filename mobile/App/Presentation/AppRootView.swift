import Observation
import SwiftUI

struct AppRootView: View {
    let container: AppContainer
    @Bindable var sessionStore: AppSessionStore

    var body: some View {
        switch sessionStore.state {
        case .restoring:
            ProgressView()
        case .entry:
            EntryView(viewModel: container.makeEntryViewModel(sessionStore: sessionStore))
        case .authenticated:
            FoundationTabView()
        case .initialProfile:
            InitialProfileHandoffView()
        }
    }
}

private struct InitialProfileHandoffView: View {
    var body: some View {
        ContentUnavailableView {
            Label("access.initial_profile.title", systemImage: "person.crop.circle")
        } description: {
            Text("access.initial_profile.description")
        }
    }
}
