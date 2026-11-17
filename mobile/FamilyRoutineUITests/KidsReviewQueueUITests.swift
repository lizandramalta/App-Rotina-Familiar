import XCTest

/// SPEC-013 Phase 2 / UX-013 §5.1: TEL-015 and the Admin-only shortcut in TEL-050 with deterministic data.
@MainActor
final class KidsReviewQueueUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
    }

    private var shortcut: XCUIElement {
        app.buttons["family.overview.kids_confirmations"]
    }

    private func openQueue() {
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()
        // Figma 870:26998: circular back + large title instead of a navigation bar. The back button only exists on
        // TEL-015, so it proves navigation (the TEL-050 shortcut also reads "Confirmações Kids").
        XCTAssertTrue(app.buttons["kidsReview.queue.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Confirmações Kids"].waitForExistence(timeout: 5))
    }

    func testAdminOpensQueueWithPendingSignalsOldestFirst() {
        launch("kids-review-queue")
        openQueue()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'kidsReview.queue.row.'")
        )
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(app.staticTexts["Da sinalização mais antiga para a mais recente."].exists)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Arrumar a cama"))
        XCTAssertTrue(rows.element(boundBy: 2).label.contains("Lavar a louça"))
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Com foto"))
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Sem foto"))
    }

    func testEmptyQueueExplainsThereIsNothingToReview() {
        launch("kids-review-queue-empty")
        openQueue()

        XCTAssertTrue(app.descendants(matching: .any)["kidsReview.queue.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Não há tarefas aguardando avaliação."].exists)
    }

    func testFailureOffersRetry() {
        launch("kids-review-queue-failure")
        openQueue()

        XCTAssertTrue(app.staticTexts["Não foi possível carregar a fila"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Verifique sua conexão e tente novamente."].exists)
        XCTAssertTrue(app.buttons["kidsReview.queue.retry"].exists)
    }

    func testMemberDoesNotSeeTheShortcut() {
        launch("family-overview-member")

        XCTAssertTrue(app.descendants(matching: .any)["app.tab_bar"].buttons["Família"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Maria Silva"].waitForExistence(timeout: 5))
        XCTAssertFalse(shortcut.exists)
    }

    /// SCRUM-126 Phase 5: with incentive cards above it, the shortcut can be scrolled fully clear of the floating
    /// tab bar and opens TEL-015 with a single tap.
    func testShortcutStaysTappableBelowIncentiveCards() {
        launch("family-overview-incentives")
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        var swipes = 0
        while !shortcut.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(shortcut.isHittable)
        let tabBar = app.descendants(matching: .any)["app.tab_bar"]
        if tabBar.exists {
            XCTAssertLessThanOrEqual(shortcut.frame.maxY, tabBar.frame.minY, "the card ends above the floating tab bar")
        }
        shortcut.tap()
        // Figma 870:26998: circular back + large title instead of a navigation bar. The back button only exists on
        // TEL-015, so it proves navigation (the TEL-050 shortcut also reads "Confirmações Kids").
        XCTAssertTrue(app.buttons["kidsReview.queue.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Confirmações Kids"].waitForExistence(timeout: 5))
    }

}
