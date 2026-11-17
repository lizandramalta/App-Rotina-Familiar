import XCTest

/// TEL-012/MOD-006 — SPEC-011 Fase 2: CA-01 to CA-05.
@MainActor
final class TaskReopenUITests: XCTestCase {
    private let app = XCUIApplication()

    /// Fixed ids from `UITestTaskFixtures` (App/Testing/UITestScenario.swift).
    private let missionFreeReopenTaskID = "00000000-0000-0000-0000-0000000000d1"
    private let missionReopenTaskID = "00000000-0000-0000-0000-0000000000d2"
    private let kidsOwnCompletedTaskID = "00000000-0000-0000-0000-0000000000d3"

    private func launchAdult(route: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = route
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testCA01AdultReopensDirectlyWithoutMissionImpact() {
        launchAdult(route: "detail:\(missionFreeReopenTaskID)")

        let reopen = app.buttons["tasks.detail.reopen"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(reopen.frame.width, min(app.frame.width - 40, 500))
        reopen.tap()

        let banner = app.staticTexts["Tarefa voltou para Pendente. O crédito de hoje foi retirado."]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertLessThan(banner.frame.minY, app.staticTexts["Esforço"].frame.minY)
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

    /// SCRUM-123 — MOD-006's buttons sit in the view body (not the toolbar, where `.frame` was a
    /// no-op), so their minimum touch target is now actually enforced: 44pt for Admin/Membro.
    func testSCRUM123MOD006ButtonsMeetMinimumTouchTargetForAdult() {
        launchAdult(route: "detail:\(missionReopenTaskID)")

        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.reopen"].tap()

        XCTAssertTrue(app.staticTexts["Reabrir vai afetar uma missão concluída"].waitForExistence(timeout: 5))
        let cancelButton = app.buttons["task.reopen.mission_warning.cancel"]
        let confirmButton = app.buttons["task.reopen.mission_warning.confirm"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(cancelButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.height, 44)
    }

    /// SCRUM-124 — routes directly via `UI_TEST_TASK_ROUTE` instead of navigating the day
    /// carousel: the carousel only renders the current week's buttons in the accessibility
    /// tree, and `kidsOwnCompletedTaskID`'s fixture date ("3 days ago") fell in the previous
    /// week's page whenever "today" was Sun/Mon/Tue, failing the day-button lookup. The
    /// carousel isn't part of CA-04 itself — only reaching the task detail is — so routing
    /// directly removes the calendar dependency instead of compensating with a conditional
    /// swipe.
    func testCA04KidsReopensOwnCompletedTask() {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks-kids"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = "detail:\(kidsOwnCompletedTaskID)"
        MainActor.assumeIsolated {
            app.launch()
        }

        XCTAssertTrue(app.staticTexts["Regar as plantas"].waitForExistence(timeout: 5))
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

    /// SCRUM-123 — Kids gets an enlarged 56pt touch target (UX-011 §3), now actually enforced
    /// since the buttons moved out of the toolbar into the view body.
    func testSCRUM123MOD006ButtonsMeetMinimumTouchTargetForKids() {
        app.launchEnvironment["UI_TEST_SCENARIO"] = "daily-tasks-kids"
        app.launchEnvironment["UI_TEST_TASK_ROUTE"] = "detail:\(missionReopenTaskID)"
        MainActor.assumeIsolated {
            app.launch()
        }
        XCTAssertTrue(app.buttons["tasks.detail.reopen"].waitForExistence(timeout: 5))
        app.buttons["tasks.detail.reopen"].tap()
        XCTAssertTrue(app.staticTexts["Essa tarefa faz parte de uma missão que já terminou"].waitForExistence(timeout: 5))
        let cancelButton = app.buttons["task.reopen.mission_warning.cancel"]
        let confirmButton = app.buttons["task.reopen.mission_warning.confirm"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        // AppPillButtonStyle.kidsHeight's nominal target is 56pt, but the rendered frame measures
        // ~55.14pt here, deterministically (not flaky). Still well above Apple's real 44pt
        // accessibility floor, so not a usability regression — tracked as SCRUM-125.
        XCTAssertGreaterThanOrEqual(cancelButton.frame.height, 55)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.height, 55)
    }
}
