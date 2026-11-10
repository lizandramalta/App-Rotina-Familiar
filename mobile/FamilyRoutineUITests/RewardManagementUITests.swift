import XCTest

@MainActor
final class RewardManagementUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launch(scenario: String = "reward-management") {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    /// UF-11: TEL-020 -> TEL-023, Administrador apenas (CA-05).
    func testAdminOpensRewardItemsFromMissionsList() {
        launch()
        XCTAssertTrue(app.buttons["missions.list.reward_items"].waitForExistence(timeout: 5))

        app.buttons["missions.list.reward_items"].tap()

        XCTAssertTrue(app.staticTexts["Escolher o filme da noite"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Noite de pizza"].exists)
    }

    /// CA-05: Membro não vê o atalho para o catálogo de recompensas.
    func testMemberDoesNotSeeTheRewardItemsAction() {
        launch(scenario: "reward-management-member")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["missions.list.reward_items"].exists)
    }

    /// UX-015 §5.1: a seção de personalizados mostra orientação, sem esconder os predefinidos.
    func testEmptyCustomSectionShowsGuidanceWithPredefinedStillVisible() {
        launch(scenario: "reward-management-empty")
        app.buttons["missions.list.reward_items"].tap()

        XCTAssertTrue(app.staticTexts["Escolher o filme da noite"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rewards.items.custom.empty"].exists)
    }

    /// CA-02: cadastra um item válido e o vê aparecer na lista, sem declarar vínculo com missão.
    func testAddingAValidItemClosesTheSheetAndShowsItInTheList() {
        launch()
        app.buttons["missions.list.reward_items"].tap()
        XCTAssertTrue(app.buttons["rewards.items.add"].waitForExistence(timeout: 5))

        app.buttons["rewards.items.add"].tap()
        let titleField = app.textFields["rewards.editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Sobremesa especial")

        app.buttons["rewards.editor.submit"].tap()

        XCTAssertTrue(app.staticTexts["Sobremesa especial"].waitForExistence(timeout: 5))
    }

    /// CA-04: título duplicado mantém o rascunho e mostra o erro inline, sem fechar o modal.
    func testDuplicateTitleKeepsTheDraftAndShowsTheInlineError() {
        launch()
        app.buttons["missions.list.reward_items"].tap()
        app.buttons["rewards.items.add"].tap()

        let titleField = app.textFields["rewards.editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Noite de pizza")
        app.buttons["rewards.editor.submit"].tap()

        XCTAssertTrue(app.staticTexts["rewards.editor.title_error"].waitForExistence(timeout: 5))
        XCTAssertEqual(titleField.value as? String, "Noite de pizza")
    }
}
