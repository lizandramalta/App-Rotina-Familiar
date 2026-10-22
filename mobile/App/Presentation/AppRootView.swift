import Observation
import SwiftUI

struct AppRootView: View {
    let container: AppContainer
    @Bindable var sessionStore: AppSessionStore
    @State private var inviteJoin: InviteJoinCoordinator
    @State private var didBootstrap = false

    init(container: AppContainer, sessionStore: AppSessionStore) {
        self.container = container
        self.sessionStore = sessionStore
        _inviteJoin = State(initialValue: container.makeInviteJoinCoordinator(sessionStore: sessionStore))
    }

    var body: some View {
        Group {
            switch sessionStore.state {
            case .restoring:
                ProgressView()
            case .entry:
                EntryView(viewModel: container.makeEntryViewModel(sessionStore: sessionStore))
            case let .authenticated(profile):
                AuthenticatedHomeView(session: profile) {
                    container.makeProfileViewModel(session: profile, sessionStore: sessionStore)
                }
                    .id(profile.memberID)
            case let .initialProfile(grant):
                InitialOnboardingFlowView(
                    viewModel: container.makeOnboardingViewModel(grant: grant, sessionStore: sessionStore)
                )
            }
        }
        .onOpenURL { url in
            Task { await inviteJoin.open(url) }
        }
        .alert("accessSwitch.title", isPresented: $inviteJoin.showsSwitchConfirmation) {
            Button("accessSwitch.cancel", role: .cancel) { inviteJoin.cancelSwitch() }
            Button("accessSwitch.confirm") { Task { await inviteJoin.confirmSwitch() } }
        } message: {
            Text("accessSwitch.description")
        }
        .sheet(isPresented: $inviteJoin.isPresented) {
            InviteJoinView(coordinator: inviteJoin)
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            #if DEBUG
            if let scenario = UITestScenario.current {
                scenario.bootstrap(sessionStore)
                if let value = ProcessInfo.processInfo.environment["UI_TEST_INVITE_URL"],
                   let url = URL(string: value) {
                    await inviteJoin.open(url)
                }
                return
            }
            #endif
            let resumed = await inviteJoin.resumePendingAttempt()
            if !resumed {
                await sessionStore.restore()
            }
            await inviteJoin.handleRestoredState()
        }
    }
}
