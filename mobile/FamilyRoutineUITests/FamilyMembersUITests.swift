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
        XCTAssertTrue(app.staticTexts["Família Silva"].exists)
        XCTAssertTrue(app.staticTexts["Membros · 2"].exists)
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(memberRows.count, 2)
        XCTAssertTrue(addAction.exists)
    }

    func testAdminRenamesFamilyAndTitleFollows() {
        launch("family-overview")

        openSettingsHub()
        app.buttons["family.settings.hub.family_name"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.clearAndTypeText("Família Souza")
        app.alerts.buttons["Salvar"].tap()

        XCTAssertTrue(app.staticTexts["Família Souza"].waitForExistence(timeout: 5))
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

    // MARK: SPEC-004 Phase 2 — invite issue and reissue (TEL-032 / TEL-034)

    private func openKidDetail() {
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Rafa Silva"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
    }

    private func dismissShareSheet() {
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func testFirstInviteOpensShareSheetThenRequiresReissueConfirmation() {
        launch("member-invite")
        openKidDetail()

        // CA-01: direct issuance, no confirmation screen.
        let issue = app.buttons["memberInvite.issue.title"]
        XCTAssertTrue(issue.waitForExistence(timeout: 5))
        issue.tap()
        XCTAssertFalse(app.buttons["memberInvite.reissue.action"].exists)
        dismissShareSheet()

        // CA-08: closing keeps the member and warns that a new invite is needed.
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.share.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["Senha: ABC-123"].exists, "credentials are never shown in the app")

        // CA-02: the next attempt goes through TEL-034 and its explicit confirmation.
        let reissue = app.buttons["memberInvite.reissue.title"]
        XCTAssertTrue(reissue.exists)
        reissue.tap()
        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.effects"].waitForExistence(timeout: 5))
        let confirm = app.buttons["memberInvite.reissue.action"]
        XCTAssertTrue(confirm.exists)
        XCTAssertTrue(app.buttons["memberInvite.cancel.action"].exists)

        app.buttons["memberInvite.cancel.action"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))

        reissue.tap()
        XCTAssertTrue(app.buttons["memberInvite.reissue.action"].waitForExistence(timeout: 5))
        app.buttons["memberInvite.reissue.action"].tap()
        dismissShareSheet()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5), "closing the sheet returns to TEL-032")
    }

    func testUncertainInviteShowsNoCredentialsAndNextAttemptIsReissue() {
        launch("member-invite-uncertain")
        openKidDetail()

        app.buttons["memberInvite.issue.title"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        XCTAssertTrue(app.buttons["memberInvite.reissue.title"].exists)
        XCTAssertFalse(app.buttons["memberInvite.issue.title"].exists)
    }

    func testCreatorDetailHasNoInviteAction() {
        launch("member-invite")
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Maria Silva"].tap()

        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memberInvite.issue.title"].exists)
        XCTAssertFalse(app.buttons["memberInvite.reissue.title"].exists)
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
