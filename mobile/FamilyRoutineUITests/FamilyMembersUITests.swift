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

    /// The `family-tasks` fixture's default overview range is *today* (mirroring the backend daily
    /// default, RN60/RN61), not a hardcoded one, so the "Limpar disabled" assertions here and in
    /// `testFamilyFilterSheetsApplyOnlyFromShowTasksButton` hold on any run date.
    func testFamilyTasksMatchesApprovedTEL011AndFiltersStatus() {
        // SPEC-009 CA-06/07/12; UX-009 TEL-011; SPEC-019 CA-05–07.
        launch("family-tasks")
        let allTasks = app.buttons["family.overview.progress"]
        XCTAssertTrue(allTasks.waitForExistence(timeout: 12))
        allTasks.tap()

        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["app.tab_bar"].exists, "TEL-011 is a full-screen destination")
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
        XCTAssertFalse(app.buttons["family.tasks.filter.clear"].isEnabled,
                       "RN60/RN61: today + Todos is the default, so Limpar starts disabled")
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

    /// SCRUM-119: the "PENDENTES" header count must match the rows actually listed once filtered
    /// by a member, including a task shared with someone else — not just the unfiltered total.
    func testFamilyTasksPendingCountMatchesListedRowsWhenFilteredByMember() {
        launch("family-tasks")
        let allTasks = app.buttons["family.overview.progress"]
        XCTAssertTrue(allTasks.waitForExistence(timeout: 12))
        allTasks.tap()

        XCTAssertTrue(app.staticTexts["Tarefas da família"].waitForExistence(timeout: 5))
        // Fixed id from `UITestTaskFixtures.memberID` (App/Testing/UITestScenario.swift).
        app.buttons["family.tasks.member.00000000-0000-0000-0000-0000000000A1"].tap()

        XCTAssertTrue(app.staticTexts["PENDENTES · 2"].waitForExistence(timeout: 5))
        let pendingRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.tasks.row.'")
        )
        XCTAssertEqual(pendingRows.count, 3, "own tasks: 2 pending (one exclusive, one shared) + 1 completed")
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
                       "RN60/RN61: the daily default (today) leaves Limpar disabled")
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

    func testIncentiveCardDismissesAfterCongratulating() {
        // RN60/RN61 (SPEC-009 E-13; UX-009 TEL-050; Figma 920:8186/920:8200): each update card has one action.
        launch("family-overview-incentives")

        let completedToday = app.staticTexts["Rafa Silva terminou todas as tarefas de hoje!"]
        let mostTasks = app.staticTexts["Rafa Silva está com muitas tarefas hoje."]
        XCTAssertTrue(completedToday.waitForExistence(timeout: 5))
        XCTAssertTrue(mostTasks.exists)
        let congratulateButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'family.incentive.congratulate.'")
        )
        let viewRafaTasks = app.buttons.matching(NSPredicate(format: "label == 'Ver tarefas de Rafa'"))
        // Parabenizar lives only on the completed-today card; "Ver tarefas" only on the most-tasks card.
        XCTAssertEqual(congratulateButtons.count, 1)
        XCTAssertEqual(viewRafaTasks.count, 1)

        congratulateButtons.firstMatch.tap()

        // Only the card with Parabenizar leaves; no "PARABÉNS ENVIADO" stays on screen.
        XCTAssertTrue(completedToday.waitForNonExistence(timeout: 5))
        XCTAssertEqual(congratulateButtons.count, 0)
        XCTAssertFalse(app.buttons["PARABÉNS ENVIADO"].exists)
        XCTAssertFalse(app.staticTexts["Você bateu palmas"].exists, "no applause caption on the remaining card")
        XCTAssertTrue(mostTasks.exists, "the most-tasks card has no Parabenizar and stays")
        XCTAssertEqual(viewRafaTasks.count, 1)
        XCTAssertTrue(app.staticTexts["Atualizações"].exists)
    }

    func testOwnMostTasksUsesCompactCardAndOpensOwnTasks() {
        launch("family-overview-own-most-tasks")

        let ownCard = app.buttons["family.incentive.own_most_tasks"]
        XCTAssertTrue(ownCard.waitForExistence(timeout: 5))
        XCTAssertTrue(ownCard.label.contains("Você está entre quem teve mais tarefas neste período"))
        XCTAssertTrue(ownCard.label.contains("Ver minhas tarefas"))
        XCTAssertTrue(app.staticTexts["Rafa Silva está com muitas tarefas hoje."].exists, "Tied other members retain the regular card")
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'family.incentive.congratulate.'")).count,
            0,
            "Most-tasks cards offer only 'Ver tarefas'; Parabenizar belongs to the completed-today card (Figma 920:8200)"
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

    // MARK: SPEC-004 Phase 2 — invite issuance (TEL-032 / TEL-034 share sheet)

    private func openKidDetail() {
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Rafa Silva'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["app.tab_bar"].exists, "TEL-032 is a full-screen destination")
    }

    func testMemberDetailSwitchesDayAndWeekAndKeepsFamilyNavigationSeparate() {
        // SPEC-009 CA-07; UX-009 TEL-032: a compact day/week list stays separate from TEL-011.
        launch("family-tasks")
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Rafa Silva'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["app.tab_bar"].exists, "TEL-032 is a full-screen destination")
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
        // UX-003 §5.2/§5.4: the selection closes the picker and opens MOD-010 before saving.
        let changeTitle = app.staticTexts["family.member.change.title"]
        XCTAssertTrue(changeTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(changeTitle.label, "Confirmar alteração de papel")
        XCTAssertTrue(app.buttons["family.member.change.confirm"].label.contains("Confirmar"))
        let cancelChange = app.buttons["family.member.change.cancel"]
        cancelChange.tap()
        XCTAssertTrue(changeTitle.waitForNonExistence(timeout: 5), "Cancelar closes MOD-010 without saving")
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
        XCTAssertEqual(app.staticTexts["family.member.detail.role"].label, "Kids", "the role is unchanged")

        app.buttons["Remover membro"].tap()
        XCTAssertTrue(changeTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(changeTitle.label, "Remover membro?")
        XCTAssertTrue(app.staticTexts["O acesso será removido. O histórico da família será preservado."].exists)
        XCTAssertTrue(app.buttons["family.member.change.confirm"].label.contains("Remover"))
        app.buttons["family.member.change.cancel"].tap()
        XCTAssertTrue(changeTitle.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
    }

    func testAdminCanDeleteKidsAccountFromMemberDetail() {
        // SPEC-022 CA-16; UX-022 UX-04: the action sits in the management block, only for Kids.
        launch("member-invite")
        openKidDetail()

        let delete = app.buttons["family.member.detail.delete_account"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Excluir"].exists)
        alert.buttons["Excluir"].firstMatch.tap()

        XCTAssertFalse(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 3))
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
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.waitForExistence(timeout: 2) {
            // iOS 26 shows the share sheet as a popover: tap outside it, away from the status bar.
            dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)).tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else {
            sheet.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func testEveryInviteIssuanceOpensShareSheetDirectly() {
        launch("member-invite")
        openKidDetail()

        // CA-01: direct issuance, no confirmation screen.
        let issue = app.buttons["memberInvite.issue.title"]
        XCTAssertTrue(issue.waitForExistence(timeout: 5))
        XCTAssertTrue(issue.label.contains("Gerar convite"), issue.label)
        issue.tap()
        dismissShareSheet()

        // CA-08: closing keeps the member and warns that a new invite is needed.
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.share.cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["Senha: ABC-123"].exists, "credentials are never shown in the app")

        // SCRUM-114 / CA-02 (SPEC-004 E-05; UX-004 UX-06/UX-07): the same entry issues again directly, with the
        // same label and no warning or confirmation step.
        XCTAssertTrue(issue.exists)
        XCTAssertTrue(issue.label.contains("Gerar convite"), issue.label)
        issue.tap()
        XCTAssertFalse(app.descendants(matching: .any)["memberInvite.effects"].exists)
        dismissShareSheet()
        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5), "closing the sheet returns to TEL-032")
    }

    func testUncertainInviteShowsNoCredentialsAndNextAttemptIsDirect() {
        launch("member-invite-uncertain")
        openKidDetail()

        let issue = app.buttons["memberInvite.issue.title"]
        XCTAssertTrue(issue.waitForExistence(timeout: 5))
        issue.tap()

        XCTAssertTrue(app.descendants(matching: .any)["memberInvite.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ActivityListView"].exists)
        // CA-07: the same entry stays available and issues directly, with no confirmation screen.
        XCTAssertTrue(issue.exists)
        XCTAssertTrue(issue.isEnabled)
    }

    func testCreatorDetailHasNoInviteAction() {
        launch("member-invite")
        XCTAssertTrue(memberRings.firstMatch.waitForExistence(timeout: 5))
        memberRings.matching(NSPredicate(format: "label CONTAINS 'Maria Silva'")).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["family.member.detail.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memberInvite.issue.title"].exists)
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
