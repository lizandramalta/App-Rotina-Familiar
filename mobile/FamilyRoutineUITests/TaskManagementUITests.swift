import XCTest

@MainActor
final class TaskManagementUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launch(route: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "task-management"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = route
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testTaskDetailLoadsAndShowsTheRealTask() {
        launch(route: "detail:00000000-0000-0000-0000-0000000000b1")
        XCTAssertTrue(app.staticTexts["Arrumar os brinquedos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tasks.detail.edit"].exists)
    }

    func testTaskCreateFormAppears() {
        launch(route: "create")
        XCTAssertTrue(app.buttons["tasks.editor.save"].waitForExistence(timeout: 5))
    }

    func testEditingAnExistingTaskPreFillsTheRealData() {
        launch(route: "detail:00000000-0000-0000-0000-0000000000b1")
        XCTAssertTrue(app.staticTexts["Arrumar os brinquedos"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.edit"].tap()

        let titleField = app.textFields["tasks.editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertEqual(titleField.value as? String, "Arrumar os brinquedos")
    }
}
