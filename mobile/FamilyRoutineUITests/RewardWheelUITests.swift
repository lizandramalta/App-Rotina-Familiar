import XCTest

/// TEL-024 — SPEC-017 Fase 2 (CA-06, CA-07, CA-08), UX-017 (UX-CA-01 a UX-CA-05) · SCRUM-90.
@MainActor
final class RewardWheelUITests: XCTestCase {
    private let app = XCUIApplication()
    /// "Semana organizada": completed, redeemable mission of the UI test fixtures.
    private let completedMissionID = "00000000-0000-0000-0000-0000000000e2"

    private func launch(scenario: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["UI_TEST_MISSION_ROUTE"] = "detail:\(completedMissionID)"
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    private func label(_ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func openWheelAndDraw() {
        let redeem = app.buttons["missions.detail.redeem"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 5))
        redeem.tap()
        XCTAssertTrue(label("Escolher recompensa").waitForExistence(timeout: 5))
        XCTAssertTrue(label("O sorteio só vale depois que você aceitar.").exists)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        let draw = app.buttons["reward.wheel.draw"]
        XCTAssertTrue(draw.waitForExistence(timeout: 5))
        draw.tap()
        // UX-CA-02: the local result says it is not saved yet.
        let result = app.otherElements["reward.wheel.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(result.label.contains("Esta recompensa ainda não foi confirmada."), result.label)
    }

    func testAdminDrawsAgainAndAcceptsAndDetailShowsReward() {
        launch(scenario: "mission-reward")
        openWheelAndDraw()

        // CA-06: drawing again keeps everything local.
        app.buttons["reward.wheel.draw_again"].tap()
        XCTAssertTrue(app.otherElements["reward.wheel.result"].waitForExistence(timeout: 8))

        app.buttons["reward.wheel.accept"].tap()

        // CA-08: back on TEL-021 with the confirmed reward and no redeem action.
        let reward = app.descendants(matching: .any)["missions.detail.reward"]
        XCTAssertTrue(reward.waitForExistence(timeout: 8))
        XCTAssertTrue(reward.label.hasPrefix("Recompensa escolhida"), reward.label)
        XCTAssertFalse(app.buttons["missions.detail.redeem"].exists)
    }

    func testExitWithoutAcceptingKeepsRedemptionAvailable() {
        launch(scenario: "mission-reward")
        openWheelAndDraw()

        app.buttons["reward.wheel.exit"].tap()

        XCTAssertTrue(app.buttons["missions.detail.redeem"].waitForExistence(timeout: 5))
    }

    func testConcurrentAcceptShowsAlreadyChosenAndReturnsToMission() {
        launch(scenario: "mission-reward-conflict")
        openWheelAndDraw()

        app.buttons["reward.wheel.accept"].tap()

        let alert = app.alerts["Recompensa já escolhida"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Ver missão"].tap()
        let reward = app.descendants(matching: .any)["missions.detail.reward"]
        XCTAssertTrue(reward.waitForExistence(timeout: 5))
        XCTAssertTrue(reward.label.contains("Sorvete no parque"), reward.label)
        XCTAssertFalse(app.buttons["missions.detail.redeem"].exists)
    }

    func testConsultItemsOpensReadOnlyCatalogAndReturns() {
        launch(scenario: "mission-reward")
        let redeem = app.buttons["missions.detail.redeem"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 5))
        redeem.tap()

        let consult = app.buttons["reward.wheel.consult"]
        XCTAssertTrue(consult.waitForExistence(timeout: 5))
        consult.tap()
        XCTAssertTrue(app.staticTexts["Noite de pizza"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["rewards.items.add"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["reward.wheel.draw"].waitForExistence(timeout: 5))
    }

    func testMemberHasNoRedeemAction() {
        launch(scenario: "mission-management-member")

        XCTAssertTrue(app.descendants(matching: .any)["missions.detail.reward"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["missions.detail.redeem"].exists)
    }
}
