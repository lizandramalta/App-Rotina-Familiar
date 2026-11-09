import XCTest

/// TEL-052 — SPEC-020 Fase 2 (CA-07, CA-08), UX-020 (UX-CA-01 a UX-CA-04) · SCRUM-103.
@MainActor
final class WeeklyRecognitionUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launch(scenario: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    private func openFromEntryCard() {
        let entry = app.buttons["recognition.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.label.contains("Você é destaque da semana!"), entry.label)
        entry.tap()
    }

    func testAdultOpensResultFromMyTasksAndSharesOnlyOnAction() {
        launch(scenario: "weekly-recognition")
        openFromEntryCard()

        // UX-CA-01: understandable without push or ranking; CA-07 order for VoiceOver.
        let summary = app.otherElements["recognition.summary.first"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("Fiquei em primeiro em pontos nesta semana!"), summary.label)
        XCTAssertTrue(summary.label.contains("42 pontos e 12 tarefas realizadas"), summary.label)
        XCTAssertTrue(app.staticTexts["Mande para sua família e sugira algo para vocês fazerem juntos."].exists)

        // Pushed screen hides the tab bar (screen-map 1.24).
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)

        // CA-08: editable, explicit and never declared as sent.
        let message = app.textViews["recognition.message"].exists
            ? app.textViews["recognition.message"]
            : app.textFields["recognition.message"]
        XCTAssertTrue(message.exists)
        XCTAssertTrue(app.buttons["recognition.share"].isEnabled)
        app.buttons["recognition.share"].tap()
        XCTAssertTrue(app.otherElements["recognition.summary.first"].exists)
        XCTAssertFalse(app.staticTexts["Mensagem enviada"].exists)

        app.buttons["recognition.copy"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "Mensagem copiada")).firstMatch.waitForExistence(timeout: 2))
    }

    func testKidsTieWithoutWhatsAppOffersCopyAndNoFamilyData() {
        launch(scenario: "weekly-recognition-kids-tie")
        openFromEntryCard()

        let summary = app.otherElements["recognition.summary.tie"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("Fiquei entre os primeiros em pontos nesta semana!"), summary.label)

        // UX-020 §3: WhatsApp unavailable → copy only.
        XCTAssertTrue(app.otherElements["recognition.whatsapp_unavailable"].exists
            || app.staticTexts["Não encontramos o WhatsApp neste aparelho. Copie a mensagem para enviar por outro app."].exists)
        XCTAssertFalse(app.buttons["recognition.share"].exists)
        XCTAssertTrue(app.buttons["recognition.copy"].exists)

        // UX-CA-04: Kids variant never exposes family load or PDF.
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'PDF'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'carga'")).firstMatch.exists)
    }

    func testFailureShowsErrorWithRetry() {
        launch(scenario: "weekly-recognition-failure")
        openFromEntryCard()

        let error = app.staticTexts.matching(NSPredicate(format: "label == %@", "Não foi possível abrir seu destaque agora.")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recognition.retry"].exists)
        XCTAssertFalse(app.buttons["recognition.share"].exists)
    }
}
