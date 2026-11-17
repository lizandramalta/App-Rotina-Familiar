import XCTest

/// SPEC-013 / UX-013 §5.2, §7 (UX-04) — SCRUM-115: TEL-016 labels assignees, the signaling child and date/time.
@MainActor
final class KidsSignalDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Fixture signals in `UITestKidsSignalRepository`, oldest first: "Arrumar a cama",
    /// "Guardar os brinquedos" and "Lavar a louça". Rows are addressed by id rather than counted.
    private func row(_ position: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "kidsReview.queue.row.00000000-0000-0000-0000-00000000050\(position)")
            .firstMatch
    }

    private func openQueue(_ scenario: String = "kids-review-queue") {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()

        let shortcut = app.buttons["family.overview.kids_confirmations"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()

        XCTAssertTrue(row(1).waitForExistence(timeout: 5))
        XCTAssertTrue(row(2).exists)
        XCTAssertTrue(row(3).exists)
    }

    private func openFirstSignal() {
        openSignal(atRow: 1)
    }

    private func openSignal(atRow position: Int) {
        openQueue()
        row(position).tap()
        XCTAssertTrue(app.navigationBars["Avaliar sinalização"].waitForExistence(timeout: 5))
    }

    /// UX-013 §4: back on TEL-015, without the decided "Arrumar a cama" and without any alert.
    private func assertReturnedToQueueWithoutFirstSignal(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["Confirmações Kids"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.navigationBars["Avaliar sinalização"].exists, file: file, line: line)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row(1))
        waitForExpectations(timeout: 5)
        XCTAssertTrue(row(2).exists, file: file, line: line)
        XCTAssertTrue(row(2).label.contains("Guardar os brinquedos"), file: file, line: line)
        XCTAssertTrue(row(3).exists, file: file, line: line)
        XCTAssertTrue(row(3).label.contains("Lavar a louça"), file: file, line: line)
        XCTAssertFalse(app.alerts.firstMatch.exists, file: file, line: line)
    }

    private func field(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func testDetailLabelsEachPersonAndDateField() {
        openFirstSignal()

        let assignees = field("kidsReview.detail.assignees")
        let signaledBy = field("kidsReview.detail.signaled_by")
        let signaledAt = field("kidsReview.detail.signaled_at")
        XCTAssertTrue(assignees.waitForExistence(timeout: 5))
        XCTAssertTrue(signaledBy.exists)
        XCTAssertTrue(signaledAt.exists)

        // The child is the only assignee: the same name appears under two distinct labels.
        XCTAssertTrue(assignees.label.contains("Responsáveis"))
        XCTAssertTrue(assignees.label.contains("Rafa Silva"))
        XCTAssertTrue(signaledBy.label.contains("Sinalizada por"))
        XCTAssertTrue(signaledBy.label.contains("Rafa Silva"))
        XCTAssertTrue(signaledAt.label.contains("Sinalizada em"))
    }

    /// SCRUM-117 / UX-013 §4: a successful confirmation returns to TEL-015 on its own.
    func testConfirmReturnsToQueueWithoutDecidedSignal() {
        openFirstSignal()

        let confirm = app.buttons["Confirmar tarefa"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        assertReturnedToQueueWithoutFirstSignal()
    }

    /// SCRUM-117 / UX-013 §4: a successful rejection returns to TEL-015 on its own.
    func testRejectReturnsToQueueWithoutDecidedSignal() {
        openFirstSignal()

        let reject = app.buttons["Recusar sinalização"]
        XCTAssertTrue(reject.waitForExistence(timeout: 5))
        reject.tap()

        assertReturnedToQueueWithoutFirstSignal()
    }

    /// SCRUM-117 / UX-013 §4 / SPEC-013 CA-06: a signal another Administrator already settled
    /// returns silently to TEL-015, with no error and no static "resolved" screen.
    func testAlreadySettledSignalReturnsSilentlyToQueue() {
        openQueue("kids-review-queue-stale")

        row(1).tap()

        assertReturnedToQueueWithoutFirstSignal()
    }

    /// SCRUM-122: the fixture now returns real image bytes for a signal with `hasPhoto == true`
    /// ("Arrumar a cama", the first queue row), so this exercises the loaded-photo branch for real
    /// instead of only through ViewModel unit tests.
    func testDetailShowsThePhotoWhenTheSignalHasOne() {
        openFirstSignal()

        XCTAssertTrue(app.images["Foto da sinalização"].waitForExistence(timeout: 5))
    }

    /// SCRUM-116: "Guardar os brinquedos" (second queue row) has no photo, so the Section that would
    /// hold it shows the approved no-photo copy instead of rendering nothing (UX-013 §7).
    func testDetailShowsTheNoPhotoWarningWhenTheSignalHasNone() {
        openSignal(atRow: 2)

        XCTAssertTrue(app.staticTexts["Nenhuma foto foi enviada."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["Foto da sinalização"].exists)
    }
}
