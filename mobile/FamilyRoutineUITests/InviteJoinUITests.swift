import XCTest

/// SPEC-005 Phase 2 / UX-005: deterministic TEL-003/004, MOD-013 and role routing on iPhone and iPad.
@MainActor
final class InviteJoinUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["UI_TEST_INVITE_URL"] = "https://example.invalid/invite/testtoken"
        app.launch()
    }

    func testCA06SwitchCancelKeepsAdultNavigation() {
        launch("invite-switch")
        let alert = app.alerts["Trocar de acesso?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancelar"].tap()

        XCTAssertTrue(app.buttons["Família"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.secureTextFields["invite.join.password"].exists)
    }

    func testCA08InvalidPasswordAndHelpRemainNeutral() {
        launch("invite-invalid-password")
        let password = app.secureTextFields["invite.join.password"].firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Família Silva"].exists)

        password.tap()
        password.typeText("WRONG1")
        app.buttons["invite.join.submit"].tap()
        XCTAssertTrue(app.staticTexts["A senha não confere. Revise e tente novamente."].waitForExistence(timeout: 5))

        app.buttons["Preciso de ajuda para acessar"].tap()
        XCTAssertTrue(app.staticTexts["Peça a um Administrador da sua família um novo convite para este perfil."].waitForExistence(timeout: 3))
    }

    func testCA09KidsSessionShowsOnlyKidsDestinations() {
        launch("invite-kids")
        let password = app.secureTextFields["invite.join.password"].firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("ABC234")
        app.buttons["invite.join.submit"].tap()

        XCTAssertTrue(app.buttons["Minhas tarefas"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Missões e conquistas"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Família"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Meu perfil"].firstMatch.exists)
    }

    func testCA09AdultSessionShowsAdultDestinations() {
        launch("invite-adult")
        let password = app.secureTextFields["invite.join.password"].firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("ABC234")
        app.buttons["invite.join.submit"].tap()

        XCTAssertTrue(app.buttons["Minhas tarefas"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Família"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Meu perfil"].firstMatch.exists)
    }

    func testCA08UncertainResultRecoversToKids() {
        launch("invite-recovery")
        let password = app.secureTextFields["invite.join.password"].firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("ABC234")
        app.buttons["invite.join.submit"].tap()

        XCTAssertTrue(app.buttons["Minhas tarefas"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Família"].firstMatch.exists)
    }

    func testCA08UnavailableRecoveryShowsNeutralGuidance() {
        launch("invite-recovery-unavailable")
        let password = app.secureTextFields["invite.join.password"].firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("ABC234")
        app.buttons["invite.join.submit"].tap()

        XCTAssertTrue(app.staticTexts["Não foi possível concluir o acesso por este convite."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Peça a um Administrador da sua família um novo convite para este perfil."].exists)
        XCTAssertFalse(app.buttons["Família"].firstMatch.exists)
    }
}
