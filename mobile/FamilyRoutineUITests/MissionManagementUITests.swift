import XCTest

@MainActor
final class MissionManagementUITests: XCTestCase {
    private let app = XCUIApplication()
    private let inProgressMissionID = "00000000-0000-0000-0000-0000000000e1"
    private let completedMissionID = "00000000-0000-0000-0000-0000000000e2"

    private func launch(scenario: String = "mission-management", route: String? = nil) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        if let route {
            app.launchEnvironment["UI_TEST_MISSION_ROUTE"] = route
        }
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testMissionListShowsInProgressAndCompletedSections() {
        launch()
        XCTAssertTrue(app.staticTexts["Casa pronta para o fim de semana"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Semana organizada"].exists)
        XCTAssertTrue(app.buttons["missions.list.create"].exists)
    }

    func testMemberDoesNotSeeTheCreateAction() {
        launch(scenario: "mission-management-member")
        XCTAssertTrue(app.staticTexts["Casa pronta para o fim de semana"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["missions.list.create"].exists)
    }

    func testMissionDetailShowsLinkedTasksAndEditAction() {
        launch(route: "detail:\(inProgressMissionID)")
        XCTAssertTrue(app.staticTexts["Casa pronta para o fim de semana"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["missions.detail.edit"].exists)
        XCTAssertTrue(app.staticTexts["Arrumar os brinquedos"].exists)
    }

    func testCompletedMissionHidesEditAction() {
        launch(route: "detail:\(completedMissionID)")
        XCTAssertTrue(app.staticTexts["Semana organizada"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["missions.detail.edit"].exists)
    }

    /// CA-19: Kids see the simplified projection, with no management action.
    func testKidsMissionDetailHasNoEditAction() {
        launch(scenario: "mission-management-kids", route: "detail:\(inProgressMissionID)")
        XCTAssertTrue(app.staticTexts["Casa pronta para o fim de semana"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["missions.detail.edit"].exists)
    }

    /// CA-12: Salvar stays disabled until there's a title and at least one linked task, with no
    /// backend call in between (the app never leaves the form on an empty-selection save attempt).
    func testCreateFormBlocksSaveWithoutTitleOrTasks() {
        launch(route: "create")
        let saveButton = app.buttons["missions.editor.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled)

        app.textFields["missions.editor.title"].tap()
        app.textFields["missions.editor.title"].typeText("Arrumar o quintal")
        XCTAssertFalse(saveButton.isEnabled, "still no linked task")

        app.buttons["missions.editor.select_tasks"].tap()
        let firstRow = app.staticTexts["Arrumar os brinquedos"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
        app.buttons["missions.task_picker.confirm"].tap()

        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
    }

    /// CA-18: "+ Nova tarefa" inside MOD-007 opens TEL-013 and returns with the task pre-selected.
    func testTaskPickerAddNewTaskShortcutPreSelectsIt() {
        launch(route: "create")
        app.textFields["missions.editor.title"].tap()
        app.textFields["missions.editor.title"].typeText("Arrumar o quintal")
        app.buttons["missions.editor.select_tasks"].tap()

        app.buttons["missions.task_picker.add_new_task"].tap()
        let newTaskTitleField = app.textFields["tasks.editor.title"]
        XCTAssertTrue(newTaskTitleField.waitForExistence(timeout: 5))
        newTaskTitleField.tap()
        newTaskTitleField.typeText("Tirar o lixo")
        app.buttons["P1 - Baixo Esforço"].tap()
        app.buttons["tasks.editor.save"].tap()

        let newRow = app.staticTexts["Tirar o lixo"]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "back in MOD-007 with the new task visible")

        app.buttons["missions.task_picker.confirm"].tap()
        XCTAssertTrue(app.staticTexts["Tirar o lixo"].waitForExistence(timeout: 5), "pre-selected back in TEL-022")
        XCTAssertTrue(app.buttons["missions.editor.save"].isEnabled)
    }
}
