import SwiftUI

@main
struct FamilyRoutineApp: App {
    private let configuration: AppConfiguration
    private let container: AppContainer
    @State private var sessionStore: AppSessionStore

    init() {
        do {
            configuration = try AppConfiguration()
            container = AppContainer(configuration: configuration)
            _sessionStore = State(initialValue: container.makeSessionStore())
        } catch {
            fatalError("Invalid application configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container, sessionStore: sessionStore)
                .task {
                    await sessionStore.restore()
                }
        }
    }
}
