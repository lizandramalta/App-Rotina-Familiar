import XCTest

/// TEL-012 — SPEC-010 Fase 2: CA-01/02/04/05/06.
@MainActor
final class TaskCompletionUITests: XCTestCase {
    private let app = XCUIApplication()
    private let adultTaskID = "00000000-0000-0000-0000-0000000000b1"
    private let kidsTaskID = "00000000-0000-0000-0000-0000000000b3"

    private func launch(scenario: String, taskID: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = "detail:\(taskID)"
        app.launch()
    }

    func testCA01AdminCompletesPendingTaskInline() {
        launch(scenario: "task-management", taskID: adultTaskID)

        let complete = app.buttons["tasks.detail.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(complete.frame.width, min(app.frame.width - 40, 500))
        complete.tap()

        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].label.contains("Concluída"))
        XCTAssertFalse(complete.exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testCA05AdminCompletesKidsConfirmationInline() {
        launch(scenario: "task-management", taskID: kidsTaskID)

        let complete = app.buttons["tasks.detail.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].label.contains("Concluída"))
        XCTAssertFalse(complete.exists)
    }

    func testCA04MemberCannotCompleteKidsTask() {
        launch(scenario: "task-completion-member", taskID: kidsTaskID)

        XCTAssertTrue(app.staticTexts["Guardar a roupa"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tasks.detail.complete"].exists)
        // SPEC-009 CA-11 / UX-009: the Member sees Pendente while the Kids signal awaits Admin review.
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].label.contains("Pendente"))
        XCTAssertTrue(app.staticTexts["A confirmação é feita por um Administrador."].exists)
        XCTAssertTrue(app.descendants(matching: .any)["tasks.detail.assignees"].label.contains("Rafa Silva"))
    }

    func testCA04MemberCanCompleteAdultTask() {
        launch(scenario: "task-completion-member", taskID: adultTaskID)

        let complete = app.buttons["tasks.detail.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].label.contains("Concluída"))
    }

    func testCA06ConflictReloadsCanonicalCompletedState() {
        launch(scenario: "task-completion-conflict", taskID: adultTaskID)

        let complete = app.buttons["tasks.detail.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()

        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].label.contains("Concluída"))
        XCTAssertFalse(complete.exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
}
