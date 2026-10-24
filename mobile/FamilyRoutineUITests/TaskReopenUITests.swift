import XCTest

/// TEL-012/MOD-006 — SPEC-011 Fase 2: CA-01 to CA-05.
@MainActor
final class TaskReopenUITests: XCTestCase {
    private let app = XCUIApplication()

    /// Fixed ids from `UITestTaskFixtures` (App/Testing/UITestScenario.swift).
    private let missionFreeReopenTaskID = "00000000-0000-0000-0000-0000000000d1"
    private let missionReopenTaskID = "00000000-0000-0000-0000-0000000000d2"

    private func launchAdult(route: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = route
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testCA01AdultReopensDirectlyWithoutMissionImpact() {
        launchAdult(route: "detail:\(missionFreeReopenTaskID)")

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.reopen"].tap()

        XCTAssertTrue(app.staticTexts["Tarefa voltou para Pendente. O crédito de hoje foi retirado."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tasks.detail.reopen"].exists, "a pending task no longer offers Reabrir")
    }

    func testCA02CA03MissionImpactShowsMOD006ThenConfirms() {
        launchAdult(route: "detail:\(missionReopenTaskID)")

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.reopen"].tap()

        XCTAssertTrue(app.staticTexts["Reabrir vai afetar uma missão concluída"].waitForExistence(timeout: 5))
        app.buttons["task.reopen.mission_warning.confirm"].tap()

        XCTAssertTrue(app.staticTexts["Tarefa voltou para Pendente. O crédito de hoje foi retirado."].waitForExistence(timeout: 5))
    }

    func testCA02CancellingMOD006KeepsTaskCompleted() {
        launchAdult(route: "detail:\(missionReopenTaskID)")

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.reopen"].tap()

        XCTAssertTrue(app.staticTexts["Reabrir vai afetar uma missão concluída"].waitForExistence(timeout: 5))
        app.buttons["task.reopen.mission_warning.cancel"].tap()

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5), "cancelling keeps the task completed, still offering Reabrir")
    }

    func testCA04KidsReopensOwnCompletedTask() {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks-kids"
        MainActor.assumeIsolated {
            app.launch()
        }

        XCTAssertTrue(app.staticTexts["Guardar as roupas limpas"].waitForExistence(timeout: 5))
        let threeDaysAgo = Self.wireString(from: Calendar(identifier: .gregorian).date(byAdding: .day, value: -3, to: Date())!)
        app.buttons["tasks.daily.day.\(threeDaysAgo)"].tap()

        XCTAssertTrue(app.staticTexts["Regar as plantas"].waitForExistence(timeout: 5))
        app.staticTexts["Regar as plantas"].tap()

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tasks.detail.edit"].exists, "Kids never edits a task, even their own (SPEC-007)")
        XCTAssertFalse(app.buttons["tasks.detail.delete"].exists, "Kids never deletes a task, even their own (SPEC-007)")
    }

    func testCA05KidsNeverSeesReopenOnAThirdPartyTask() {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks-kids"
        MainActor.assumeIsolated {
            app.launch()
        }

        XCTAssertTrue(app.staticTexts["Escovar os dentes"].waitForExistence(timeout: 5))
        app.staticTexts["Escovar os dentes"].tap()

        XCTAssertTrue(app.staticTexts["Escovar os dentes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tasks.detail.reopen"].exists, "not responsible for this task, so Reabrir must stay hidden (CA-05)")
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
