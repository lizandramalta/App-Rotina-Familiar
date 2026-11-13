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
        rows.element(boundBy: index).tap()
        XCTAssertTrue(app.navigationBars["Avaliar sinalização"].waitForExistence(timeout: 5))
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
    }

    /// SCRUM-116: "Guardar os brinquedos" (second queue row) has no photo, so the Section that would
    /// hold it shows the approved no-photo copy instead of rendering nothing (UX-013 §7).
    func testDetailShowsTheNoPhotoWarningWhenTheSignalHasNone() {
        openSignal(atRow: 1)

        XCTAssertTrue(app.staticTexts["Nenhuma foto foi enviada."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["Foto da sinalização"].exists)
    }
}
