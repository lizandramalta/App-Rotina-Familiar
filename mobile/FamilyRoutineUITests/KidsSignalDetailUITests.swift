import XCTest

/// SPEC-013 / UX-013 §5.2, §7 (UX-04) — SCRUM-115: TEL-016 labels assignees, the signaling child and date/time.
@MainActor
final class KidsSignalDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openFirstSignal() {
        openSignal(atRow: 0)
    }

    private func openSignal(atRow index: Int) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "kids-review-queue"
        app.launch()

        let shortcut = app.buttons["family.overview.kids_confirmations"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'kidsReview.queue.row.'")
        )
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let title = ["Arrumar a cama", "Guardar os brinquedos", "Lavar a louça"][index]
        rows.element(boundBy: index).tap()
        // Figma 870:27124: TEL-016 replaces the navigation bar with a circular back button + large title.
        XCTAssertTrue(app.buttons["kidsReview.detail.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
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
        openSignal(atRow: 1)

        XCTAssertTrue(app.staticTexts["Nenhuma foto foi enviada."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["Foto da sinalização"].exists)
    }
}
