import XCTest

/// TEL-010/TEL-040 — SPEC-009 Fase 1: CA-01, CA-02, CA-03, CA-04, CA-09, CA-11.
@MainActor
final class DailyTaskListUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launch(scenario: String) {
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        MainActor.assumeIsolated {
            app.launch()
        }
    }

    func testAdultSeesTodaysTasksWithPendingLabelAndProgress() {
        launch(scenario: "daily-tasks")

        XCTAssertTrue(app.staticTexts["Passear com o cachorro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Guardar as roupas limpas"].exists)
        XCTAssertTrue(app.staticTexts["Escovar os dentes"].exists)
        XCTAssertTrue(app.staticTexts["Hoje | 3 Tarefas"].exists)
        let ownTask = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Passear com o cachorro")).firstMatch
        let sharedTask = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Guardar as roupas limpas")).firstMatch
        XCTAssertTrue(ownTask.label.contains("Você, P1 - Baixo Esforço"), ownTask.label)
        XCTAssertTrue(sharedTask.label.contains("Você e Rafa Silva, P2 - Médio Esforço"), sharedTask.label)
        XCTAssertTrue(app.otherElements["tasks.daily.progress"].exists)

        // SPEC-009 CA-11 / UX-009: visual status leaves the adult subtitle; VoiceOver retains it.
        XCTAssertFalse(app.staticTexts["Pendente"].exists)
        XCTAssertFalse(app.staticTexts["Aguardando confirmação"].exists)

        // CA-04/adult-only: can create a new task from here.
        XCTAssertTrue(app.buttons["tasks.daily.new"].exists)
        ownTask.tap()
        XCTAssertTrue(app.buttons["tasks.detail.edit"].waitForExistence(timeout: 5))
    }

    func testKidsSeesAwaitingConfirmationLabelAndNoCreateAction() {
        launch(scenario: "daily-tasks-kids")

        XCTAssertTrue(app.staticTexts["Guardar as roupas limpas"].waitForExistence(timeout: 5))
        // CA-11: the same shared task reads "Aguardando confirmação" for Kids, not "Pendente".
        XCTAssertTrue(app.staticTexts["Aguardando confirmação"].exists)

        // CA-04: Kids never gets the create action or any family/navigation surface here.
        XCTAssertFalse(app.buttons["tasks.daily.new"].exists)
    }

    func testKidsReceivesGroupedApplauseAndCanHideIt() {
        launch(scenario: "daily-tasks-kids-applause")

        XCTAssertTrue(app.staticTexts["Alex e Sam bateram palmas para você!"].waitForExistence(timeout: 5))
        app.buttons["Fechar mensagem"].tap()
        XCTAssertFalse(app.staticTexts["Alex e Sam bateram palmas para você!"].exists)
    }

    func testSelectingAnEmptyDayShowsSemTarefas() {
        launch(scenario: "daily-tasks")
        XCTAssertTrue(app.staticTexts["Passear com o cachorro"].waitForExistence(timeout: 5))

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let today = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let emptyDay = (0 ..< 7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .first { !calendar.isDate($0, inSameDayAs: today) && !calendar.isDate($0, inSameDayAs: threeDaysAgo) }!
        app.buttons["tasks.daily.day.\(Self.wireString(from: emptyDay))"].tap()

        XCTAssertTrue(app.staticTexts["Sem tarefas para este dia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tarefas atribuídas a você aparecem aqui."].exists)
        XCTAssertTrue(app.buttons["tasks.daily.empty_new"].exists)
        XCTAssertTrue(app.otherElements["tasks.daily.progress"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "TEL-010 empty day"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["tasks.daily.empty_new"].tap()
        XCTAssertTrue(app.buttons["tasks.editor.save"].waitForExistence(timeout: 5))
    }

    func testLoadFailureShowsRetryableErrorNotEmpty() {
        launch(scenario: "daily-tasks-failure")

        XCTAssertTrue(app.staticTexts["Não foi possível atualizar suas tarefas. Tente novamente."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Tentar novamente"].exists)
        XCTAssertTrue(app.staticTexts["tasks.daily.load_error"].exists)
        XCTAssertFalse(app.staticTexts["Sem tarefas para este dia"].exists)
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
