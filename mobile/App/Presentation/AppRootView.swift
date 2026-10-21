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
        case let .initialProfile(grant):
            InitialOnboardingFlowView(
                viewModel: container.makeOnboardingViewModel(grant: grant, sessionStore: sessionStore)
            )
        }
    }
}
