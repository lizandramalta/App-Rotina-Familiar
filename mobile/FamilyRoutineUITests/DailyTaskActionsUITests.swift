import XCTest

/// TEL-010 — SPEC-010 CA-01 and SPEC-011 CA-01: the circle acts, the rest of the row navigates.
@MainActor
final class DailyTaskActionsUITests: XCTestCase {
    private let app = XCUIApplication()
    private let pendingTaskID = "00000000-0000-0000-0000-0000000000C1"
    private let completedTaskID = "00000000-0000-0000-0000-0000000000C3"

    private func launch(scenario: String = "task-management") {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
    }

    func testCircleCompletesAndReopensWithoutOpeningDetail() {
        launch()
        let toggle = app.buttons["tasks.daily.toggle.\(pendingTaskID)"]
        let row = app.buttons["tasks.daily.row.\(pendingTaskID)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(row.exists)

        toggle.tap()
        let completedRow = app.buttons["tasks.daily.row.\(pendingTaskID)"]
        XCTAssertTrue(completedRow.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Concluída"), evaluatedWith: completedRow)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["tasks.detail.reopen"].exists)

        app.buttons["tasks.daily.toggle.\(pendingTaskID)"].tap()
        let pendingRow = app.buttons["tasks.daily.row.\(pendingTaskID)"]
        XCTAssertTrue(pendingRow.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Pendente"), evaluatedWith: pendingRow)
        waitForExpectations(timeout: 5)
    }

    func testCompletedCircleReopensAndRowStillOpensDetail() {
        launch()
        let toggle = app.buttons["tasks.daily.toggle.\(completedTaskID)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let row = app.buttons["tasks.daily.row.\(completedTaskID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Pendente"), evaluatedWith: row)
        waitForExpectations(timeout: 5)

        row.tap()
        XCTAssertTrue(app.buttons["tasks.detail.complete"].waitForExistence(timeout: 5))
    }

    func testSecondTapUpdatesImmediatelyWhileFirstWriteIsRunning() {
        launch(scenario: "task-optimistic-delayed")
        let toggle = app.buttons["tasks.daily.toggle.\(pendingTaskID)"]
        let row = app.buttons["tasks.daily.row.\(pendingTaskID)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        toggle.tap()
        XCTAssertTrue(row.label.contains("Concluída"), "The row should change before the delayed response")
        toggle.tap()
        XCTAssertTrue(row.label.contains("Pendente"), "The second tap should change the row immediately")
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(row.label.contains("Pendente"), "The final server result follows the latest intent")
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testRejectedWriteRestoresRowAndShowsAlert() {
        launch(scenario: "task-optimistic-failure")
        let toggle = app.buttons["tasks.daily.toggle.\(pendingTaskID)"]
        let row = app.buttons["tasks.daily.row.\(pendingTaskID)"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        toggle.tap()
        XCTAssertTrue(app.alerts["Não foi possível alterar a tarefa"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pendente"))
    }
}
