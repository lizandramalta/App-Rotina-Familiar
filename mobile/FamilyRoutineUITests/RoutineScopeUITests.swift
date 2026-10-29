import XCTest

/// SCRUM-109 / SPEC-008 Fase 2, UX-008 §4 and §5.3: Editar and Excluir on a routine occurrence
/// always go through MOD-003 before TEL-013 or MOD-005.
@MainActor
final class RoutineScopeUITests: XCTestCase {
    private let app = XCUIApplication()
    private let routineOccurrenceRoute = "detail:00000000-0000-0000-0000-0000000000b5"

    private func launch() {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "task-management"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = routineOccurrenceRoute
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEditingThisAndFutureOpensTheFormWithDateAndRecurrenceLocked() {
        launch()
        let edit = app.buttons["tasks.detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let confirm = app.buttons["routines.scope.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Onde aplicar esta alteração?"].exists)
        XCTAssertFalse(confirm.isEnabled)
        attach("MOD-003 edit scope")

        app.buttons["routines.scope.selected_and_future"].tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Editar tarefa"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.datePickers["tasks.editor.scheduled_date"].isEnabled)
        let recurrence = app.descendants(matching: .any)["tasks.editor.recurrence_readonly"]
        XCTAssertTrue(recurrence.waitForExistence(timeout: 5))
        XCTAssertTrue(recurrence.label.contains("A cada 7 dias"), recurrence.label)
        attach("TEL-013 edit this and future")

        app.buttons["tasks.editor.save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
    }

    func testCancelingTheScopeKeepsTheDetail() {
        launch()
        let edit = app.buttons["tasks.detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let cancel = app.buttons["routines.scope.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Editar tarefa"].exists)
    }

    func testDeletingThisAndFutureAsksTheScopeThenConfirms() {
        launch()
        let delete = app.buttons["tasks.detail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(app.staticTexts["O que excluir?"].waitForExistence(timeout: 5))
        app.buttons["routines.scope.selected_and_future"].tap()
        attach("MOD-003 delete scope")
        app.buttons["routines.scope.confirm"].tap()

        let alert = app.alerts["Excluir esta tarefa?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Excluir"].tap()
        XCTAssertTrue(app.buttons["tasks.daily.new"].waitForExistence(timeout: 5))
    }
}
