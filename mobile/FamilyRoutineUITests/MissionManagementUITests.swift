import XCTest

@MainActor
final class MissionManagementUITests: XCTestCase {
    private let app = XCUIApplication()
    private let inProgressMissionID = "00000000-0000-0000-0000-0000000000e1"
    private let completedMissionID = "00000000-0000-0000-0000-0000000000e2"
    private let rewardedMissionID = "00000000-0000-0000-0000-0000000000e3"

    private func element(labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// SwiftUI doesn't surface `accessibilityIdentifier` on `List` row buttons, so rows are found by
    /// their combined accessible label, which starts with the mission title.
    private func row(_ missionID: String) -> XCUIElement {
        let titles = [
            inProgressMissionID: "Casa pronta para o fim de semana",
            completedMissionID: "Semana organizada",
            rewardedMissionID: "Quarto arrumado",
        ]
        let title = titles[missionID] ?? missionID
        return app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

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

    // MARK: - SPEC-016 Fase 2 (SCRUM-86)

    /// CA-01/CA-02/CA-05: cards show canonical fraction + percent and the true reward situation.
    func testListCardsShowProgressAndRewardState() {
        launch()
        let inProgress = row(inProgressMissionID)
        XCTAssertTrue(inProgress.waitForExistence(timeout: 5))
        // awaitingConfirmation is not counted: 0 of 2.
        XCTAssertTrue(inProgress.label.contains("0 de 2 tarefas concluídas (0%)"))
        XCTAssertTrue(inProgress.label.contains("2 tarefas faltam"))
        XCTAssertTrue(app.staticTexts["Missões da família"].exists)
        XCTAssertTrue(app.staticTexts["1 em andamento · 2 concluídas"].exists)
        XCTAssertTrue(row(completedMissionID).label.contains("Recompensa pronta para resgate"))
        XCTAssertTrue(row(rewardedMissionID).label.contains("Recompensa escolhida: Noite de pizza"))
    }

    /// CA-03: Admin sees progress, accepted reward and participations, with no redemption action.
    func testAdultDetailShowsRewardAndParticipations() {
        launch(route: "detail:\(rewardedMissionID)")
        XCTAssertTrue(app.staticTexts["Quarto arrumado"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(labeled: "1 de 1 tarefas concluídas (100%)").exists)
        XCTAssertTrue(element(labeled: "Recompensa escolhida: Noite de pizza").exists)
        // "Quem já ajudou": names joined (Figma 579-59).
        XCTAssertTrue(element(labeled: "Ana Silva, Rafa Silva").exists)
    }

    /// CA-03: Kids see the accepted reward but neither participations nor management actions.
    func testKidsDetailShowsRewardWithoutParticipations() {
        launch(scenario: "mission-management-kids")
        let rewarded = row(rewardedMissionID)
        XCTAssertTrue(rewarded.waitForExistence(timeout: 5))
        rewarded.tap()
        XCTAssertTrue(element(labeled: "Recompensa escolhida: Noite de pizza").waitForExistence(timeout: 5))
        XCTAssertFalse(element(labeled: "Ana Silva, Rafa Silva").exists)
        XCTAssertFalse(app.staticTexts["Quem já ajudou"].exists)
        XCTAssertFalse(app.buttons["missions.detail.edit"].exists)
    }

    /// CA-05 / E-2: Kids are never told a reward is "pronta para resgate".
    func testKidsListNeverAnnouncesRedemption() {
        launch(scenario: "mission-management-kids")
        let completed = row(completedMissionID)
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertFalse(completed.label.contains("Recompensa pronta para resgate"))
        XCTAssertTrue(completed.label.contains("Nenhuma recompensa foi escolhida ainda."))
    }

    /// CA-07: a failed pull-to-refresh keeps the confirmed cards and shows a retryable banner.
    func testRefreshFailureKeepsCardsAndShowsBanner() {
        launch(scenario: "mission-tracking-refresh-failure")
        let inProgress = row(inProgressMissionID)
        XCTAssertTrue(inProgress.waitForExistence(timeout: 5))

        let start = inProgress.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 400))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(app.buttons["missions.refresh_error.retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(inProgress.exists, "confirmed content stays visible")
    }

    /// Figma 579-59 trail: Kids see "SUA VEZ!" on their own linked task, which opens TEL-041.
    func testKidsTrailMarksOwnTask() {
        launch(scenario: "mission-management-kids")
        let inProgress = row(inProgressMissionID)
        XCTAssertTrue(inProgress.waitForExistence(timeout: 5))
        inProgress.tap()
        let ownNode = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Guardar a roupa,")).firstMatch
        XCTAssertTrue(ownNode.waitForExistence(timeout: 5))
        XCTAssertTrue(ownNode.label.contains("SUA VEZ!"))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrumar os brinquedos,")).firstMatch.exists)
    }

    /// The tab bar belongs to each tab's root route only; pushed screens hide it.
    func testTabBarOnlyOnRootRoute() {
        launch()
        let missionsTab = app.tabBars.buttons["Missões"]
        let inProgress = row(inProgressMissionID)
        XCTAssertTrue(inProgress.waitForExistence(timeout: 5))
        XCTAssertTrue(missionsTab.exists, "root route shows the tab bar")

        inProgress.tap()
        XCTAssertTrue(app.buttons["missions.detail.edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(missionsTab.exists, "mission detail hides the tab bar")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(missionsTab.waitForExistence(timeout: 5), "back on the root, the tab bar returns")
    }

    func testKidsMissionDetailHidesTabBar() {
        launch(scenario: "mission-management-kids")
        // Scoped to the tab bar: the detail's back button also reads "Missões e conquistas".
        let kidsTab = app.tabBars.buttons["Missões e conquistas"]
        let inProgress = row(inProgressMissionID)
        XCTAssertTrue(inProgress.waitForExistence(timeout: 5))
        XCTAssertTrue(kidsTab.exists)

        inProgress.tap()
        XCTAssertTrue(app.staticTexts["Casa pronta para o fim de semana"].waitForExistence(timeout: 5))
        XCTAssertFalse(kidsTab.exists)
    }
}
