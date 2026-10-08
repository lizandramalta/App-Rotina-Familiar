import SwiftUI

@main
struct FamilyRoutineApp: App {
    private let configuration: AppConfiguration

    init() {
        do {
            configuration = try AppConfiguration()
        } catch {
            fatalError("Invalid application configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            FoundationTabView()
        }
    }
}
