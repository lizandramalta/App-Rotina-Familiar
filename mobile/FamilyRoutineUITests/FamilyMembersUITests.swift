import XCTest

/// SPEC-003 Phase 1 / UX-003: TEL-050, TEL-032 and TEL-033 with deterministic data.
@MainActor
final class FamilyMembersUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
    }

    private var memberRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.member.row.'")
        )
    }

    private var memberRings: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.member.ring.'")
        )
    }

    private var addAction: XCUIElement {
        app.buttons["family.members.add.action"]
    }

    private var settingsButton: XCUIElement {
        app.buttons["family.navigation.settings_button"]
    }

    private func openSettingsHub() {
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Configurações da família"].waitForExistence(timeout: 5))
    }

    func testAdminSeesAddActionAndCanOpenMemberDetail() {
        launch("family-overview")

        let familyTab = app.buttons["Família"].firstMatch
        XCTAssertTrue(familyTab.waitForExistence(timeout: 5))
        XCTAssertTrue(familyTab.isSelected)
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(memberRings.count, 2)
        XCTAssertTrue(memberRings.allElementsBoundByIndex.contains { $0.label.contains("Maria Silva") })
        XCTAssertTrue(memberRings.allElementsBoundByIndex.contains { $0.label.contains("Rafa Silva") })
        XCTAssertTrue(settingsButton.exists)
        XCTAssertFalse(addAction.exists, "TEL-050 no longer hosts the add entry")

        memberRings.matching(NSPredicate(format: "label CONTAINS 'Maria Silva'")).firstMatch.tap()

        let name = app.staticTexts["family.member.detail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Maria Silva")
        XCTAssertTrue(app.staticTexts["family.member.detail.role"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["family.member.detail.creator_badge"].exists)
        XCTAssertTrue(app.segmentedControls["family.member.detail.period"].exists)
        XCTAssertFalse(app.buttons["family.member.detail.edit_kids_name"].exists)
        XCTAssertFalse(app.buttons["family.member.detail.change_role"].exists)
    }

    func testMemberCannotSeeAddAction() {
        launch("family-overview-member")

        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(memberRings.allElementsBoundByIndex.contains { $0.label.contains("Maria Silva") })
        XCTAssertFalse(addAction.exists, "SPEC-003 CA-02: only Administrators see the add entry")
        XCTAssertFalse(settingsButton.exists)
    }

    func testFamilyTasksMatchesApprovedTEL011AndFiltersStatus() {
        // SPEC-009 CA-06/07/12; UX-009 TEL-011; SPEC-019 CA-05–07.
        launch("family-tasks")
        let allTasks = app.buttons["family.overview.progress"]
        XCTAssertTrue(allTasks.waitForExistence(timeout: 12))
        allTasks.tap()

        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists, "TEL-011 is a full-screen destination")
        XCTAssertTrue(app.buttons["family.tasks.member.all"].exists)
        XCTAssertTrue(app.staticTexts["PENDENTES · 3"].exists)
        XCTAssertTrue(app.staticTexts["AGUARDANDO CONFIRMAÇÃO · 1"].exists)
        XCTAssertTrue(app.staticTexts["CONCLUÍDAS · 2"].exists)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.tasks.row.' AND label CONTAINS 'Sem responsável'")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["family.tasks.more"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TEL-011 approved layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["family.tasks.range"].tap()
        XCTAssertTrue(app.buttons["family.tasks.status.awaitingConfirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["family.tasks.filter.clear"].isEnabled)
        let filterScreenshot = XCTAttachment(screenshot: app.screenshot())
        filterScreenshot.name = "TEL-011 filter sheet"
        filterScreenshot.lifetime = .keepAlways
        add(filterScreenshot)
        app.buttons["family.tasks.status.awaitingConfirmation"].tap()
        let apply = app.buttons["family.period.apply"]
        expectation(for: NSPredicate(format: "label CONTAINS '1 tarefa'"), evaluatedWith: apply)
        waitForExpectations(timeout: 5)
        apply.tap()
        XCTAssertTrue(app.staticTexts["AGUARDANDO CONFIRMAÇÃO · 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["PENDENTES · 3"].exists)
    }

    func testFamilyFilterSheetsApplyOnlyFromShowTasksButton() {
        // SPEC-009 CA-06/12; UX-009 TEL-050/TEL-011: tapping sheet content does not apply filters.
        launch("family-tasks")
        let overviewFilter = app.buttons["family.overview.range_filter"]
        XCTAssertTrue(overviewFilter.waitForExistence(timeout: 5))
        overviewFilter.tap()
        XCTAssertFalse(app.buttons["family.tasks.status.pending"].exists,
                       "UX-009 TEL-050 has only the period filter")
        XCTAssertFalse(app.buttons["family.overview.filter.clear"].isEnabled,
                       "The current default week leaves Limpar disabled")
        let overviewScreenshot = XCTAttachment(screenshot: app.screenshot())
        overviewScreenshot.name = "TEL-050 period filter sheet"
        overviewScreenshot.lifetime = .keepAlways
        add(overviewScreenshot)
        assertFilterSheetOnlyAppliesFromButton()

        let allTasks = app.buttons["family.overview.progress"]
        XCTAssertTrue(allTasks.waitForExistence(timeout: 5))
        allTasks.tap()
        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        app.buttons["family.tasks.range"].tap()
        XCTAssertTrue(app.buttons["family.tasks.status.pending"].waitForExistence(timeout: 5),
                      "UX-009 TEL-011 shows status chips immediately")
        XCTAssertTrue(app.buttons["family.tasks.status.pending"].isHittable)
        assertFilterSheetOnlyAppliesFromButton()
    }

    private func assertFilterSheetOnlyAppliesFromButton() {
        let apply = app.buttons["family.period.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        XCTAssertLessThan(apply.frame.height, 80)
        let title = app.staticTexts["Filtros"]
        XCTAssertTrue(title.exists)
        title.tap()
        XCTAssertTrue(apply.exists, "Tapping the sheet title must not apply filters")
        apply.tap()
        XCTAssertFalse(apply.waitForExistence(timeout: 2), "Show tasks should close the sheet")
    }

    func testIncentiveCardsAllowRepeatedApplauseToAnotherMember() {
        launch("family-overview-incentives")

        XCTAssertTrue(app.staticTexts["Terminou todas as tarefas de hoje!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Teve muitas tarefas neste período"].exists)
        let congratulate = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.incentive.congratulate.'")
        ).firstMatch
        XCTAssertTrue(congratulate.exists)
        congratulate.tap()
        XCTAssertTrue(app.buttons["PARABÉNS ENVIADO"].waitForExistence(timeout: 5))
        app.buttons["PARABÉNS ENVIADO"].firstMatch.tap()
        XCTAssertTrue(app.buttons["PARABÉNS ENVIADO"].exists)
    }

    func testOwnMostTasksUsesCompactCardAndOpensOwnTasks() {
        launch("family-overview-own-most-tasks")

        let ownCard = app.buttons["family.incentive.own_most_tasks"]
        XCTAssertTrue(ownCard.waitForExistence(timeout: 5))
        XCTAssertTrue(ownCard.label.contains("Você está entre quem teve mais tarefas neste período"))
        XCTAssertTrue(ownCard.label.contains("Ver minhas tarefas"))
        XCTAssertTrue(app.staticTexts["Teve muitas tarefas neste período"].exists, "Tied other members retain the regular card")
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'family.incentive.congratulate.'")).count,
            1,
            "Only the other member can be congratulated"
        )

        ownCard.tap()
        let name = app.staticTexts["family.member.detail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.label, "Maria Silva")
    }

    func testAdminOpensSettingsHubWithMembersAndAddAction() {
        launch("family-overview")

        openSettingsHub()

        XCTAssertTrue(app.staticTexts["Fuso horário"].exists)
        XCTAssertTrue(app.staticTexts["Família Silva"].exists)
        XCTAssertTrue(app.staticTexts["Membros · 2"].exists)
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(memberRows.count, 2)
        XCTAssertTrue(addAction.exists)
    }

    func testAdminRenamesFamilyAndTitleFollows() {
        launch("family-overview")

        openSettingsHub()
        app.buttons["family.settings.hub.family_name"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.clearAndTypeText("Família Souza")
        app.alerts.buttons["Salvar"].tap()

        XCTAssertTrue(app.staticTexts["Família Souza"].waitForExistence(timeout: 5))
    }

    func testAdminCanOpenCreateMemberFormAndSave() {
        launch("family-overview")

        openSettingsHub()
        XCTAssertTrue(addAction.waitForExistence(timeout: 5))
        addAction.tap()

        XCTAssertTrue(app.navigationBars["Adicionar membro"].waitForExistence(timeout: 5))
        let nameField = app.textFields["family.members.editor.name"]
        XCTAssertTrue(nameField.exists)
        let submit = app.buttons["family.members.editor.submit"]
        XCTAssertTrue(submit.exists)
        XCTAssertFalse(submit.isEnabled)

        nameField.tap()
        nameField.typeText("Lucas")
        let role = app.buttons["family.members.editor.role.member"]
        XCTAssertTrue(role.exists)
        role.tap()
        XCTAssertTrue(submit.isEnabled)

        submit.tap()

        XCTAssertTrue(app.navigationBars["Adicionar membro"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(memberRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(addAction.exists)
    }

    // MARK: SPEC-004 Phase 2 — invite issue and reissue (TEL-032 / TEL-034)

    private func openKidDetail() {
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Rafa Silva'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists, "TEL-032 is a full-screen destination")
    }

    func testMemberDetailSwitchesDayAndWeekAndKeepsFamilyNavigationSeparate() {
        // SPEC-009 CA-07; UX-009 TEL-032: a compact day/week list stays separate from TEL-011.
        launch("family-tasks")
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Rafa Silva'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists, "TEL-032 is a full-screen destination")
        let period = app.segmentedControls["family.member.detail.period"]
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        XCTAssertTrue(period.buttons["Dia"].isSelected)
        XCTAssertTrue(period.buttons["Semana"].exists)
        XCTAssertFalse(app.buttons["family.incentive.congratulate"].exists)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.member.detail.task.'")
        ).firstMatch.exists)
        XCTAssertFalse(app.buttons["family.tasks.range"].exists)
        XCTAssertFalse(app.buttons["family.tasks.more"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "TEL-032 day member detail"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        period.buttons["Semana"].tap()
        XCTAssertTrue(period.buttons["Semana"].isSelected)
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.member.detail.task.'")
        ).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        app.buttons["family.member.detail.back"].tap()
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
    }

    func testFamilyTasksReturnsToItsIntervalAfterTaskDetail() {
        // SPEC-009 CA-06/07; UX-009 TEL-011: task navigation preserves the family list.
        launch("family-tasks")
        let allTasks = app.buttons["family.overview.progress"]
        XCTAssertTrue(allTasks.waitForExistence(timeout: 5))
        allTasks.tap()
        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        let task = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.tasks.row.'")
        ).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(app.staticTexts["tasks.detail.status"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["family.tasks.range"].exists)
    }

    func testMemberDetailManagementRowsKeepActionsSeparateFromTasks() {
        // SPEC-003 CA-04; UX-003 TEL-032: role management opens from its own row.
        launch("member-invite")
        openKidDetail()

        XCTAssertTrue(app.buttons["family.member.detail.edit_kids_name"].exists)
        XCTAssertTrue(app.buttons["Alterar papel"].waitForExistence(timeout: 5))
        app.buttons["Alterar papel"].tap()
        XCTAssertTrue(app.navigationBars["Alterar papel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancelar"].exists)
        XCTAssertTrue(app.buttons["family.member.role.option.member"].exists)
        app.buttons["family.member.role.option.member"].tap()
        XCTAssertTrue(app.alerts["Confirmar alteração de papel?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)

        app.buttons["Remover membro"].tap()
        XCTAssertTrue(app.alerts["Remover membro"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
    }

    func testAdminEditsKidsNameFromMemberDetailTopButton() {
        // SPEC-003 CA-02/03/07; UX-003 TEL-032: only a Kids target exposes Editar.
        launch("member-invite")
        openKidDetail()
        let edit = app.buttons["family.member.detail.edit_kids_name"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let name = app.textFields["family.member.detail.kids_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.clearAndTypeText("Rafa Novo")
        app.buttons["Salvar"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["family.member.detail.name"].label, "Rafa Novo")
    }

    func testKidsNameIsEditedFromFamilySettings() {
        // SPEC-003 CA-02/03; UX-003 TEL-057: Kids name correction is Admin-only in settings.
        launch("family-overview")
        openSettingsHub()
        let edit = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.settings.hub.edit_kids_name.'")
        ).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields["family.settings.hub.kids_name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["family.member.detail.edit_kids_name"].exists)
        let name = app.textFields["family.settings.hub.kids_name"]
        name.tap()
        let oldName = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count) + "Rafa Novo")
        app.buttons["Salvar"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Rafa Novo'")).firstMatch.exists)
    }

    private func dismissShareSheet() {
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
        } else if app.otherElements["PopoverDismissRegion"].exists {
            app.otherElements["PopoverDismissRegion"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func testFirstInviteOpensShareSheetThenRequiresReissueConfirmation() {
        launch("member-invite")
        openKidDetail()

        // CA-01: direct issuance, no confirmation screen.
        let issue = app.buttons["memberInvite.issue.title"]
        XCTAssertTrue(issue.waitForExistence(timeout: 5))
        issue.tap()
        XCTAssertFalse(app.buttons["memberInvite.reissue.action"].exists)
        dismissShareSheet()

        // CA-08: closing keeps the member and warns that a new invite is needed.
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.share.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["Senha: ABC-123"].exists, "credentials are never shown in the app")

        // CA-02: the next attempt goes through TEL-034 and its explicit confirmation.
        let reissue = app.buttons["memberInvite.reissue.title"]
        XCTAssertTrue(reissue.exists)
        reissue.tap()
        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.effects"].waitForExistence(timeout: 5))
        let confirm = app.buttons["memberInvite.reissue.action"]
        XCTAssertTrue(confirm.exists)
        XCTAssertTrue(app.buttons["memberInvite.cancel.action"].exists)

        app.buttons["memberInvite.cancel.action"].tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))

        reissue.tap()
        XCTAssertTrue(app.buttons["memberInvite.reissue.action"].waitForExistence(timeout: 5))
        app.buttons["memberInvite.reissue.action"].tap()
        dismissShareSheet()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5), "closing the sheet returns to TEL-032")
    }

    func testUncertainInviteShowsNoCredentialsAndNextAttemptIsReissue() {
        launch("member-invite-uncertain")
        openKidDetail()

        app.buttons["memberInvite.issue.title"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        XCTAssertTrue(app.buttons["memberInvite.reissue.title"].exists)
        XCTAssertFalse(app.buttons["memberInvite.issue.title"].exists)
    }

    func testCreatorDetailHasNoInviteAction() {
        launch("member-invite")
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Maria Silva'")).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memberInvite.issue.title"].exists)
        XCTAssertFalse(app.buttons["memberInvite.reissue.title"].exists)
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let current = value as? String, !current.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
