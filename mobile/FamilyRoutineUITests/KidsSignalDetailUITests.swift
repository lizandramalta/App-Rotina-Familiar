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
        let title = ["Arrumar a cama", "Guardar os brinquedos", "Lavar a louça"][position - 1]
        row(position).tap()
        // Figma 870:27124: TEL-016 replaces the navigation bar with a circular back button + large title.
        XCTAssertTrue(app.buttons["kidsReview.detail.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    /// UX-013 §4: back on TEL-015, without the decided "Arrumar a cama" and without any alert.
    private func assertReturnedToQueueWithoutFirstSignal(file: StaticString = #filePath, line: UInt = #line) {
        // TEL-015/TEL-016 have no navigation bar (Figma 870:26998 / 870:27124): their back buttons tell them apart.
        XCTAssertTrue(app.buttons["kidsReview.queue.back"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.buttons["kidsReview.detail.back"].exists, file: file, line: line)
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

        let confirm = app.buttons["kidsReview.detail.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        assertReturnedToQueueWithoutFirstSignal()
    }

    /// SCRUM-117 / UX-013 §4: a successful rejection returns to TEL-015 on its own.
    func testRejectReturnsToQueueWithoutDecidedSignal() {
        openFirstSignal()

        let reject = app.buttons["kidsReview.detail.reject"]
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
        // Figma 870:27149/870:27162: the task observation and the private-photo hint.
        XCTAssertTrue(app.staticTexts["Esticar o lençol e alinhar os travesseiros."].exists)
        XCTAssertTrue(app.staticTexts["Foto privada · toque para ampliar"].exists)
    }

    /// SCRUM-126 Phase 4 (UX-013 §5.2/§8): tapping the photo opens the private enlarged viewer, which has no
    /// share/save action and closes back to TEL-016.
    func testPhotoOpensPrivateViewerAndCloses() {
        openFirstSignal()

        let photo = app.images["Foto da sinalização"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()

        let viewer = field("kidsReview.photo.viewer")
        XCTAssertTrue(viewer.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Compartilhar"].exists)
        XCTAssertFalse(app.buttons["Share"].exists)
        viewer.doubleTap()
        let close = app.buttons["kidsReview.photo.close"]
        XCTAssertTrue(close.exists)
        XCTAssertEqual(close.label, "Fechar")
        close.tap()

        XCTAssertTrue(viewer.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kidsReview.detail.back"].exists)
    }

    /// SCRUM-116: "Guardar os brinquedos" (second queue row) has no photo, so the Section that would
    /// hold it shows the approved no-photo copy instead of rendering nothing (UX-013 §7).
    func testDetailShowsTheNoPhotoWarningWhenTheSignalHasNone() {
        openSignal(atRow: 2)

        XCTAssertTrue(app.staticTexts["Nenhuma foto foi enviada."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["Foto da sinalização"].exists)
    }
}
