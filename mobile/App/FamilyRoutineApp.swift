import SwiftUI

@main
struct FamilyRoutineApp: App {
    private let container: AppContainer
    @State private var sessionStore: AppSessionStore

    init() {
        #if DEBUG
        if let scenario = UITestScenario.current {
            let container = scenario.makeContainer()
            self.container = container
            _sessionStore = State(initialValue: container.makeSessionStore())
            return
        }
        #endif

        do {
            let container = AppContainer(configuration: try AppConfiguration())
            self.container = container
            _sessionStore = State(initialValue: container.makeSessionStore())
        } catch {
            fatalError("Invalid application configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container, sessionStore: sessionStore)
                .task {
                    #if DEBUG
                    if let scenario = UITestScenario.current {
                        scenario.bootstrap(sessionStore)
                        return
                    }
                    #endif
                    await sessionStore.restore()
                }
        }
    }
}
