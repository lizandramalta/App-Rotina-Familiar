import XCTest

/// SPEC-006 Phase 2 / UX-006: TEL-030, MOD-009 and TEL-054 with deterministic data.
@MainActor
final class ProfileUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
    }

    private func openAdultProfile() {
        let tab = app.buttons["Perfil"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(app.staticTexts["profile.identity.title"].waitForExistence(timeout: 5))
    }

    private func openEditor() {
        let edit = app.buttons["profile.edit.button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields["profile.edit.nickname"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(text)
    }

    func testReleaseProfileHasNoPhotoControl() {
        launch("profile-adult")
        openAdultProfile()
        openEditor()

        XCTAssertFalse(app.buttons["profile.edit.photo_button"].exists)
    }

    func testAdultProfileAndBadgeDetailNavigation() {
        launch("profile-adult")
        openAdultProfile()

        XCTAssertEqual(app.staticTexts["profile.identity.title"].label, "Maria Silva")
        XCTAssertEqual(app.staticTexts["profile.identity.subtitle"].label, "Administrador · Família Silva")
        XCTAssertEqual(app.staticTexts["profile.badges.total"].label, "12 missões com participação")
        XCTAssertEqual(app.staticTexts["profile.badges.next_tier"].label, "Faltam 13 para o ouro")

        let gold = app.buttons["profile.badge.gold"]
        reveal(gold)
        XCTAssertTrue(gold.exists)
        XCTAssertFalse(gold.isEnabled, "a pending milestone is not tappable (UX-04)")
        XCTAssertTrue(app.staticTexts["PAPEL NA FAMÍLIA"].exists || { reveal(app.staticTexts["PAPEL NA FAMÍLIA"]); return app.staticTexts["PAPEL NA FAMÍLIA"].exists }())

        let silver = app.buttons["profile.badge.silver"]
        reveal(silver)
        XCTAssertTrue(silver.isEnabled)
        silver.tap()

        XCTAssertTrue(app.staticTexts["profile.badge_detail.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profile.badge_detail.title"].label, "Prata · 10 missões")
        XCTAssertTrue(app.staticTexts["Missões que contaram"].waitForExistence(timeout: 5))
        let row = app.buttons.matching(identifier: "profile.badge_detail.mission_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Organizar a sala"].exists)

        row.tap()
        XCTAssertTrue(app.otherElements["profile.badge_detail.mission_placeholder"].waitForExistence(timeout: 5)
            || app.staticTexts["Organizar a sala"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["profile.badge_detail.title"].waitForExistence(timeout: 5), "back returns to TEL-054")
    }

    func testAdultEditProfileValidationDiscardAndSave() {
        launch("profile-adult")
        openAdultProfile()
        openEditor()

        let nickname = app.textFields["profile.edit.nickname"]
        nickname.tap()
        nickname.typeText(String(repeating: "a", count: 21))
        XCTAssertTrue(app.staticTexts["A etiqueta pode ter até 20 caracteres (sem contar espaços)."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["profile.edit.save"].isEnabled)

        replaceText(in: nickname, with: "Mari")
        XCTAssertFalse(app.staticTexts["A etiqueta pode ter até 20 caracteres (sem contar espaços)."].exists)
        replaceText(in: app.textFields["profile.edit.name"], with: "Maria S.")

        app.buttons["profile.edit.close"].tap()
        let alert = app.alerts["Descartar alterações?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Continuar editando"].firstMatch.tap()
        XCTAssertFalse(alert.exists)

        XCTAssertTrue(app.buttons["profile.edit.save"].isEnabled)
        app.buttons["profile.edit.save"].tap()

        XCTAssertTrue(app.staticTexts["profile.identity.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profile.identity.title"].label, "Mari")
        XCTAssertEqual(app.staticTexts["profile.identity.subtitle"].label, "Maria S. · Administrador")
    }

    func testSaveNetworkFailurePreservesFormDraft() {
        launch("profile-save-network-error")
        openAdultProfile()
        openEditor()

        let nickname = app.textFields["profile.edit.nickname"]
        nickname.tap()
        nickname.typeText("Mari")
        app.buttons["profile.edit.save"].tap()

        XCTAssertTrue(
            app.staticTexts["Não foi possível conectar. Verifique sua internet. Seus dados continuam aqui."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(app.textFields["profile.edit.nickname"].value as? String, "Mari")
    }

    func testKidsProfileFromHeaderAndEditorWithoutNameField() {
        launch("profile-kids")
        let profileButton = app.buttons["kids.home.profile_button"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        XCTAssertTrue(app.staticTexts["profile.identity.subtitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profile.identity.subtitle"].label, "Kids · Família Silva")
        XCTAssertFalse(app.staticTexts["PAPEL NA FAMÍLIA"].exists)

        openEditor()
        XCTAssertTrue(app.staticTexts["Seu apelido"].exists)
        XCTAssertFalse(app.textFields["profile.edit.name"].exists)
        XCTAssertFalse(app.staticTexts["Seu nome"].exists)
    }
}
