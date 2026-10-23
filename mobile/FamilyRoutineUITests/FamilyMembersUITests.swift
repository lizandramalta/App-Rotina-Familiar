import XCTest

/// SPEC-003 Phase 1 / UX-003: TEL-050, TEL-032 and TEL-033 with deterministic data.
@MainActor
final class FamilyMembersUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
    }

    private var memberRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.member.row.'")
        )
    }

    private var addAction: XCUIElement {
        app.buttons["family.members.add.action"]
    }

    private var settingsButton: XCUIElement {
        app.buttons["family.navigation.settings_button"]
    }

    private func openSettingsHub() {
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Configurações da família"].waitForExistence(timeout: 5))
    }

    func testAdminSeesAddActionAndCanOpenMemberDetail() {
        launch("family-overview")

        XCTAssertTrue(app.tabBars.buttons["Família"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Família"].isSelected)
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(memberRows.count, 2)
        XCTAssertTrue(app.staticTexts["Maria Silva"].exists)
        XCTAssertTrue(app.staticTexts["Rafa Silva"].exists)
        XCTAssertTrue(settingsButton.exists)
        XCTAssertFalse(addAction.exists, "TEL-050 no longer hosts the add entry")

        app.staticTexts["Maria Silva"].tap()

        let name = app.staticTexts["family.member.detail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Maria Silva")
        XCTAssertTrue(app.staticTexts["family.member.detail.role"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["family.member.detail.creator_badge"].exists)
        let notice = app.descendants(matching: .any)["family.member.detail.creator_notice"]
        XCTAssertTrue(notice.exists)
        XCTAssertTrue(app.staticTexts["O Criador da família não pode ser removido nem ter o papel alterado."].exists)
    }

    func testMemberCannotSeeAddAction() {
        launch("family-overview-member")

        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Maria Silva"].exists)
        XCTAssertFalse(addAction.exists, "SPEC-003 CA-02: only Administrators see the add entry")
        XCTAssertFalse(settingsButton.exists)
    }

    func testAdminOpensSettingsHubWithMembersAndAddAction() {
        launch("family-overview")

        openSettingsHub()

        XCTAssertTrue(app.staticTexts["Fuso horário"].exists)
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(memberRows.count, 2)
        XCTAssertTrue(addAction.exists)
    }

    func testAdminCanOpenCreateMemberFormAndSave() {
        launch("family-overview")

        openSettingsHub()
        XCTAssertTrue(addAction.waitForExistence(timeout: 5))
        addAction.tap()

        XCTAssertTrue(app.navigationBars["Adicionar membro"].waitForExistence(timeout: 5))
        let nameField = app.textFields["family.members.editor.name"]
        XCTAssertTrue(nameField.exists)
        let submit = app.buttons["family.members.editor.submit"]
        XCTAssertTrue(submit.exists)
        XCTAssertFalse(submit.isEnabled)

        nameField.tap()
        nameField.typeText("Lucas")
        let role = app.buttons["family.members.editor.role.member"]
        XCTAssertTrue(role.exists)
        role.tap()
        XCTAssertTrue(submit.isEnabled)

        submit.tap()

        XCTAssertTrue(app.navigationBars["Adicionar membro"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(addAction.exists)
    }
}
