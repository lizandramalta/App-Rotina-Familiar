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
        // SPEC-007 CA-10 / UX-007 TEL-012: show the assignee name and the Figma effort label.
        let weight = app.descendants(matching: .any)["tasks.detail.weight"]
        let assignees = app.descendants(matching: .any)["tasks.detail.assignees"]
        XCTAssertTrue(weight.label.contains("P2 - Médio Esforço"), weight.label)
        XCTAssertTrue(assignees.label.contains("Maria Silva"), assignees.label)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "TEL-012 task detail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPendingTaskCanBeDeletedAfterConfirmation() {
        launch(route: "detail:00000000-0000-0000-0000-0000000000b1")
        let delete = app.buttons["tasks.detail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        // SPEC-007 CA-09 / UX-007 MOD-005: confirmation is a native alert, not a popover menu.
        let alert = app.alerts["Excluir esta tarefa?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Arrumar os brinquedos"].exists)
        let confirm = alert.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        // SPEC-007 CA-09 / UX-007 MOD-005: the detail closes only after deletion succeeds.
        XCTAssertTrue(app.buttons["tasks.daily.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tasks.detail.delete"].exists)
    }

    func testCompletedTaskCannotBeDeletedDirectly() {
        launch(route: "detail:00000000-0000-0000-0000-0000000000b2")
        let delete = app.buttons["tasks.detail.delete_disabled"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertFalse(delete.isEnabled)
        XCTAssertTrue(app.staticTexts["Tarefas concluídas não podem ser excluídas diretamente"].exists)
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
