import XCTest

/// SCRUM-44 / SPEC-008 Fase 1 — CA-01, CA-02 and the pending state visible after saving.
@MainActor
final class RoutineCreationUITests: XCTestCase {
    func testAdultSelectsSevenDayRoutineAndSeesPreparationThenCanonicalCompletion() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "routine-creation"
        MainActor.assumeIsolated { app.launch() }

        let newTask = app.buttons["tasks.daily.new"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 5))
        newTask.tap()

        let title = app.textFields["tasks.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Regar as plantas")
        app.buttons.matching(NSPredicate(format: "label == %@", "Pouco esforço")).firstMatch.tap()
        app.buttons["tasks.editor.recurrence"].tap()

        let sevenDays = app.buttons["routines.recurrence.option.7"]
        XCTAssertTrue(sevenDays.waitForExistence(timeout: 5))
        sevenDays.tap()
        app.buttons["routines.recurrence.confirm"].tap()

        let save = app.buttons["tasks.editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts["Estamos preparando as próximas tarefas."].waitForExistence(timeout: 5))
        app.buttons["routines.list.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Rotina salva. As próximas tarefas estão disponíveis quando entrarem no período consultável."].waitForExistence(timeout: 5))
    }
}
