import XCTest

/// SPEC-002 Phase 1 / UX-002: TEL-055, TEL-002, TEL-033 and the post-creation hand-off, against stubbed repositories.
@MainActor
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        XCTAssertTrue(app.textFields["profile.initial.name"].waitForExistence(timeout: 5))
    }

    private func type(_ text: String, into identifier: String) {
        let field = app.textFields[identifier]
        field.tap()
        field.typeText(text)
    }

    private func openFamilyStep(name: String = "Maria Silva") {
        type(name, into: "profile.initial.name")
        app.buttons["profile.initial.continue"].tap()
        XCTAssertTrue(app.textFields["family.create.name"].waitForExistence(timeout: 3))
    }

    private func assertMainAppOpened() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testProfileRequiresNameAndBackPreservesTheDraft() {
        launch("onboarding")

        app.buttons["profile.initial.continue"].tap()
        XCTAssertTrue(app.staticTexts["Informe seu nome para continuar."].waitForExistence(timeout: 2))

        openFamilyStep(name: "Maria")
        app.buttons["family.create.back"].tap()

        XCTAssertTrue(app.textFields["profile.initial.name"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["profile.initial.name"].value as? String, "Maria")
    }

    func testCancelAsksForConfirmationAndReturnsToEntry() {
        launch("onboarding")

        app.buttons["profile.initial.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Descartar criação?"].waitForExistence(timeout: 2))
        // The system presents the dialog as a popover on this OS, which has no explicit cancel button.
        app.otherElements["PopoverDismissRegion"].firstMatch.tap()
        XCTAssertTrue(app.textFields["profile.initial.name"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Descartar criação?"].exists)

        app.buttons["profile.initial.cancel"].tap()
        app.buttons["profile.initial.discard_confirm"].firstMatch.tap()

        XCTAssertTrue(app.buttons["access.entry.apple_button"].waitForExistence(timeout: 3))
    }

    func testFamilyNameIsRequiredAndTimeZoneDefaultsToSaoPaulo() {
        launch("onboarding")
        openFamilyStep()

        XCTAssertEqual(app.buttons["family.create.timezone"].value as? String, "America/Sao_Paulo")
        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.staticTexts["Informe o nome da família para continuar."].waitForExistence(timeout: 2))
    }

    func testTimeZoneCanBeSearchedAndSelected() {
        launch("onboarding")
        openFamilyStep()

        app.buttons["family.create.timezone"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Lisbon")
        app.buttons["family.timezone.option.Europe/Lisbon"].tap()

        XCTAssertEqual(app.buttons["family.create.timezone"].value as? String, "Europe/Lisbon")
    }

    func testMemberDraftCanBeAddedEditedAndRemoved() {
        launch("onboarding")
        openFamilyStep()

        app.buttons["family.members.add"].tap()
        let nameField = app.textFields["family.members.draft.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        app.buttons["family.members.draft.save"].tap()
        XCTAssertTrue(app.staticTexts["Informe o nome do membro."].waitForExistence(timeout: 2))

        nameField.tap()
        nameField.typeText("Pedro")
        app.buttons["family.members.draft.save"].tap()
        XCTAssertTrue(app.buttons["family.members.row"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Pedro"].exists)

        app.buttons["family.members.row"].tap()
        XCTAssertTrue(app.buttons["family.members.draft.remove"].waitForExistence(timeout: 3))
        app.buttons["family.members.draft.remove"].tap()

        XCTAssertTrue(app.buttons["family.members.add"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["family.members.row"].exists)
    }

    func testCreatingWithoutMembersOpensTheMainApp() {
        launch("onboarding")
        openFamilyStep()
        type("Casa Silva", into: "family.create.name")

        app.buttons["family.create.submit"].tap()

        assertMainAppOpened()
    }

    func testCreatingWithMembersOffersExplicitInvitesBeforeEntering() {
        launch("onboarding")
        openFamilyStep()
        type("Casa Silva", into: "family.create.name")
        app.buttons["family.members.add"].tap()
        let nameField = app.textFields["family.members.draft.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Pedro")
        app.buttons["family.members.draft.save"].tap()
        XCTAssertTrue(app.staticTexts["Pedro"].waitForExistence(timeout: 3))

        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.otherElements["family.onboarding.invite_members"].waitForExistence(timeout: 5)
            || app.collectionViews["family.onboarding.invite_members"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["family.onboarding.finish_invites"].isEnabled)

        app.buttons["family.onboarding.invite_button"].tap()

        let closeButton = app.buttons["Close"].exists ? app.buttons["Close"] : app.buttons["Fechar"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
        }

        XCTAssertTrue(app.buttons["family.onboarding.finish_invites"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["family.onboarding.finish_invites"].isEnabled)
        app.buttons["family.onboarding.finish_invites"].tap()
        assertMainAppOpened()
    }

    func testSkippingInvitesEntersTheMainApp() {
        launch("onboarding")
        openFamilyStep()
        type("Casa Silva", into: "family.create.name")
        app.buttons["family.members.add"].tap()
        let nameField = app.textFields["family.members.draft.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Joana")
        app.buttons["family.members.draft.save"].tap()
        XCTAssertTrue(app.staticTexts["Joana"].waitForExistence(timeout: 3))
        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.buttons["family.onboarding.skip_invites"].waitForExistence(timeout: 5))
        app.buttons["family.onboarding.skip_invites"].tap()

        assertMainAppOpened()
    }

    func testUncertainOutcomeOffersAccessVerification() {
        launch("onboarding-uncertain")
        openFamilyStep()
        type("Casa Silva", into: "family.create.name")

        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.staticTexts["family.create.uncertain_banner"].waitForExistence(timeout: 5)
            || app.otherElements["family.create.uncertain_banner"].waitForExistence(timeout: 1))
        XCTAssertEqual(app.textFields["family.create.name"].value as? String, "Casa Silva")

        app.buttons["family.create.verify_access"].tap()

        XCTAssertTrue(app.buttons["access.entry.apple_button"].waitForExistence(timeout: 3))
    }

    func testPhotoFailureCanBeRetriedWithoutRecreatingTheFamily() {
        launch("onboarding-photo-failure")
        app.buttons["profile.initial.continue"].tap()
        XCTAssertTrue(app.textFields["family.create.name"].waitForExistence(timeout: 3))
        type("Casa Silva", into: "family.create.name")

        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.buttons["profile.initial.photo_retry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.initial.photo_skip"].exists)
        XCTAssertFalse(app.buttons["family.create.submit"].exists)

        app.buttons["profile.initial.photo_retry"].tap()

        assertMainAppOpened()
    }

    func testPhotoFailureCanBeSkipped() {
        launch("onboarding-photo-failure")
        app.buttons["profile.initial.continue"].tap()
        XCTAssertTrue(app.textFields["family.create.name"].waitForExistence(timeout: 3))
        type("Casa Silva", into: "family.create.name")
        app.buttons["family.create.submit"].tap()

        XCTAssertTrue(app.buttons["profile.initial.photo_skip"].waitForExistence(timeout: 5))
        app.buttons["profile.initial.photo_skip"].tap()

        assertMainAppOpened()
    }
}
