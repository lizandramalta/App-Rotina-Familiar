import XCTest

/// TEL-010/TEL-040 — SPEC-009 Fase 1: CA-01, CA-02, CA-03, CA-04, CA-09, CA-11.
@MainActor
final class DailyTaskListUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launch(scenario: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testAdultSeesTodaysTasksWithPendingLabelAndProgress() {
        launch(scenario: "daily-tasks")

        XCTAssertTrue(app.staticTexts["Passear com o cachorro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Guardar as roupas limpas"].exists)
        XCTAssertTrue(app.staticTexts["Escovar os dentes"].exists)
        XCTAssertTrue(app.staticTexts["1/3"].exists)

        // CA-11: the adult never sees "Aguardando confirmação" in their own list.
        XCTAssertFalse(app.staticTexts["Aguardando confirmação"].exists)

        // CA-04/adult-only: can create a new task from here.
        XCTAssertTrue(app.buttons["tasks.daily.new"].exists)
    }

    func testKidsSeesAwaitingConfirmationLabelAndNoCreateAction() {
        launch(scenario: "daily-tasks-kids")

        XCTAssertTrue(app.staticTexts["Guardar as roupas limpas"].waitForExistence(timeout: 5))
        // CA-11: the same shared task reads "Aguardando confirmação" for Kids, not "Pendente".
        XCTAssertTrue(app.staticTexts["Aguardando confirmação"].exists)

        // CA-04: Kids never gets the create action or any family/navigation surface here.
        XCTAssertFalse(app.buttons["tasks.daily.new"].exists)
    }

    func testSelectingAnEmptyDayShowsSemTarefas() {
        launch(scenario: "daily-tasks")
        XCTAssertTrue(app.staticTexts["Passear com o cachorro"].waitForExistence(timeout: 5))

        let yesterday = Self.wireString(from: Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date())!)
        app.buttons["tasks.daily.day.\(yesterday)"].tap()

        XCTAssertTrue(app.staticTexts["Sem tarefas para este dia"].waitForExistence(timeout: 5))
    }

    func testLoadFailureShowsRetryableErrorNotEmpty() {
        launch(scenario: "daily-tasks-failure")

        XCTAssertTrue(app.staticTexts["Não foi possível atualizar suas tarefas. Tente novamente."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
        XCTAssertFalse(app.staticTexts["Sem tarefas para este dia"].exists)
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
