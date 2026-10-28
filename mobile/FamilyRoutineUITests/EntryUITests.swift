import XCTest

@MainActor
final class EntryUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testEntryShowsTheAppleActionAndAccessibleWelcomeContent() {
        XCTAssertTrue(app.staticTexts["Bem-vindo ao Mutua"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.images["Ilustração de uma casa com porta e janelas, representando o lar da família"].exists)
        XCTAssertTrue(app.buttons["access.entry.apple_button"].exists)
    }
}
