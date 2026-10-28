import Observation
import SwiftUI

struct AppRootView: View {
    let container: AppContainer
    let pushRegistration: PushDeviceRegistration
    @Bindable var sessionStore: AppSessionStore
    @State private var inviteJoin: InviteJoinCoordinator
    @State private var didBootstrap = false

    init(container: AppContainer, sessionStore: AppSessionStore, pushRegistration: PushDeviceRegistration) {
        self.container = container
        self.pushRegistration = pushRegistration
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
                if profile.role == .kid {
                    NavigationStack {
                        ContentUnavailableView {
                            Label("release.kids_unavailable.title", systemImage: "person.crop.circle.badge.xmark")
                        } description: {
                            Text("release.kids_unavailable.message")
                        } actions: {
                            Button("release.kids_unavailable.sign_out") {
                                Task { await sessionStore.signOut() }
                            }
                        }
                    }
                } else {
                AuthenticatedHomeView(
                    session: profile,
                    myTasksTab: sessionStore.accessToken.map {
                        container.makeMyTasksTabView(session: profile, accessToken: $0)
                    },
                    makeFamilyOverviewViewModel: {
                        container.makeFamilyOverviewViewModel(session: profile, sessionStore: sessionStore)
                    },
                    makeFamilySettingsViewModel: {
                        container.makeFamilySettingsViewModel(session: profile, sessionStore: sessionStore)
                    }
                ) {
                    container.makeProfileViewModel(session: profile, sessionStore: sessionStore)
                }
                .id(profile)
                .task(id: profile.memberID) {
                    if let token = sessionStore.accessToken {
                        await container.registerPushDevice(accessToken: token, registration: pushRegistration)
                    }
                }
                }
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
