import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-016 Fase 2 (SCRUM-86) — TEL-020 list behaviour: CA-01/02/03/05 presentation, CA-07 recovery.
@MainActor
struct MissionListViewModelTests {
    private func makeSummary(
        title: String,
        status: MissionStatus,
        taskCount: Int = 2,
        completedTaskCount: Int? = nil,
        progressPercent: Double? = nil,
        isRedemptionAvailable: Bool? = false,
        acceptedReward: AcceptedMissionReward? = nil
    ) -> MissionSummary {
        let completed = completedTaskCount ?? (status == .completed ? taskCount : 0)
        return MissionSummary(
            id: UUID(),
            title: title,
            status: status,
            taskCount: taskCount,
            completedTaskCount: completed,
            progressPercent: progressPercent ?? (taskCount == 0 ? 0 : Double(completed) / Double(taskCount) * 100),
            isRedemptionAvailable: isRedemptionAvailable,
            acceptedReward: acceptedReward
        )
    }

    private func makeViewModel(_ repository: MissionRepositorySpy, role: MemberRole = .administrator) -> MissionListViewModel {
        MissionListViewModel(repository: repository, role: role, accessToken: "token")
    }

    @Test("RN37: only Administrador sees the 'Nova missão' action")
    func onlyAdminCanCreate() {
        let repository = MissionRepositorySpy()
        #expect(makeViewModel(repository, role: .administrator).canCreate)
        #expect(!makeViewModel(repository, role: .member).canCreate)
        #expect(!makeViewModel(repository, role: .kid).canCreate)
    }

    @Test("CA-01: keeps the server's in-progress/completed collections and canonical progress as-is")
    func keepsCanonicalCollections() async {
        let inProgress = makeSummary(title: "Casa pronta", status: .inProgress, taskCount: 3, completedTaskCount: 1, progressPercent: 33.333)
        let completed = makeSummary(title: "Semana organizada", status: .completed, isRedemptionAvailable: true)
        let repository = MissionRepositorySpy(missionsResult: .success(MissionCollections(inProgress: [inProgress], completed: [completed])))
        let viewModel = makeViewModel(repository)

        await viewModel.load()

        #expect(viewModel.inProgress == [inProgress])
        #expect(viewModel.completed == [completed])
        #expect(viewModel.hasLoaded)
        #expect(!viewModel.loadFailed)
    }

    @Test("CA-02: an awaitingConfirmation task keeps 0 of 2 — the app shows the server's count, never recalculates")
    func awaitingConfirmationIsNotCounted() async {
        let mission = makeSummary(title: "Casa pronta", status: .inProgress, taskCount: 2, completedTaskCount: 0, progressPercent: 0)
        let repository = MissionRepositorySpy(missionsResult: .success(MissionCollections(inProgress: [mission], completed: [])))
        let viewModel = makeViewModel(repository)

        await viewModel.load()

        #expect(viewModel.inProgress.first?.completedTaskCount == 0)
        #expect(displayedProgressPercent(viewModel.inProgress.first?.progressPercent ?? -1) == 0)
    }

    @Test("Displayed percent rounds down so it never reads 100% before completion (E-3)")
    func displayedPercentRoundsDown() {
        #expect(displayedProgressPercent(99.9) == 99)
        #expect(displayedProgressPercent(33.333) == 33)
        #expect(displayedProgressPercent(100) == 100)
        #expect(displayedProgressPercent(0) == 0)
    }

    @Test("CA-05: completed without acceptance says 'pronta para resgate' to adults, accepted shows the title")
    func rewardStateForAdults() {
        let viewModel = makeViewModel(MissionRepositorySpy())
        let available = makeSummary(title: "A", status: .completed, isRedemptionAvailable: true)
        let accepted = makeSummary(
            title: "B",
            status: .completed,
            isRedemptionAvailable: false,
            acceptedReward: AcceptedMissionReward(rewardItemID: UUID(), title: "Noite de pizza")
        )
        let inProgress = makeSummary(title: "C", status: .inProgress, isRedemptionAvailable: false)

        #expect(viewModel.rewardState(for: available) == .redemptionAvailable)
        #expect(viewModel.rewardState(for: accepted) == .accepted(title: "Noite de pizza"))
        #expect(viewModel.rewardState(for: inProgress) == .none)
    }

    @Test("CA-03/E-2: Kids (no isRedemptionAvailable) see the accepted reward, otherwise 'nenhuma recompensa'")
    func rewardStateForKids() {
        let viewModel = makeViewModel(MissionRepositorySpy(), role: .kid)
        let notAccepted = makeSummary(title: "A", status: .completed, isRedemptionAvailable: nil)
        let accepted = makeSummary(
            title: "B",
            status: .completed,
            isRedemptionAvailable: nil,
            acceptedReward: AcceptedMissionReward(rewardItemID: UUID(), title: "Noite de pizza")
        )

        #expect(viewModel.rewardState(for: notAccepted) == .none)
        #expect(viewModel.rewardState(for: accepted) == .accepted(title: "Noite de pizza"))
    }

    @Test("An empty response is reflected as the empty state, not as a skeleton")
    func emptyList() async {
        let viewModel = makeViewModel(MissionRepositorySpy())

        #expect(!viewModel.hasLoaded)
        await viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.hasLoaded)
        #expect(!viewModel.showsSkeleton)
    }

    @Test("CA-07: an initial load failure is a full-screen recoverable error, and retry recovers")
    func initialFailureThenRetry() async {
        let repository = MissionRepositorySpy(missionsResult: .failure(MissionError.network))
        let viewModel = makeViewModel(repository)

        await viewModel.load()
        #expect(viewModel.loadFailed)
        #expect(!viewModel.refreshFailed)

        let mission = makeSummary(title: "Casa pronta", status: .inProgress)
        repository.setMissionsResult(.success(MissionCollections(inProgress: [mission], completed: [])))
        await viewModel.load()

        #expect(!viewModel.loadFailed)
        #expect(viewModel.inProgress == [mission])
        #expect(repository.missionsCallCount == 2)
    }

    @Test("CA-07: a failed refresh keeps confirmed cards and only raises the non-blocking banner")
    func refreshFailureKeepsConfirmedContent() async {
        let mission = makeSummary(title: "Casa pronta", status: .inProgress)
        let repository = MissionRepositorySpy(missionsResult: .success(MissionCollections(inProgress: [mission], completed: [])))
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        repository.setMissionsResult(.failure(MissionError.unavailable))
        await viewModel.load()

        #expect(viewModel.inProgress == [mission])
        #expect(viewModel.refreshFailed)
        #expect(!viewModel.loadFailed)

        viewModel.dismissRefreshError()
        #expect(!viewModel.refreshFailed)
    }

    @Test("CA-06: a confirmed reopening is reflected by the next query — no stale reward is kept")
    func reopenedMissionIsReflectedOnRefresh() async {
        let id = UUID()
        let completed = MissionSummary(
            id: id, title: "Semana organizada", status: .completed, taskCount: 2, completedTaskCount: 2,
            progressPercent: 100, isRedemptionAvailable: false,
            acceptedReward: AcceptedMissionReward(rewardItemID: UUID(), title: "Noite de pizza")
        )
        let reopened = MissionSummary(
            id: id, title: "Semana organizada", status: .inProgress, taskCount: 2, completedTaskCount: 1,
            progressPercent: 50, isRedemptionAvailable: false, acceptedReward: nil
        )
        let repository = MissionRepositorySpy(missionsResult: .success(MissionCollections(inProgress: [], completed: [completed])))
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        repository.setMissionsResult(.success(MissionCollections(inProgress: [reopened], completed: [])))
        await viewModel.load()

        #expect(viewModel.completed.isEmpty)
        #expect(viewModel.inProgress == [reopened])
        #expect(viewModel.rewardState(for: reopened) == .none)
    }

    @Test("Hero summary: adults see in-progress/completed counts; Kids see the collective count, hidden at zero")
    func heroSubtitle() async {
        let collections = MissionCollections(
            inProgress: [makeSummary(title: "A", status: .inProgress), makeSummary(title: "B", status: .inProgress)],
            completed: [makeSummary(title: "C", status: .completed)]
        )
        let adult = makeViewModel(MissionRepositorySpy(missionsResult: .success(collections)))
        #expect(adult.heroSubtitle == nil, "nothing before the first confirmed response")
        await adult.load()
        #expect(adult.heroSubtitle == missionsHeroSummaryText(inProgress: 2, completed: 1))

        let kids = makeViewModel(MissionRepositorySpy(missionsResult: .success(collections)), role: .kid)
        await kids.load()
        #expect(kids.heroSubtitle == missionsHeroKidsSummaryText(completed: 1))

        let kidsNone = makeViewModel(MissionRepositorySpy(missionsResult: .success(MissionCollections(inProgress: collections.inProgress, completed: []))), role: .kid)
        await kidsNone.load()
        #expect(kidsNone.heroSubtitle == nil)
    }

    @Test("Plural copy resolves the pt-BR one/other variants from the catalog")
    func pluralCopy() {
        #expect(missionTasksRemainingText(taskCount: 2, completedTaskCount: 1) == "1 tarefa falta")
        #expect(missionTasksRemainingText(taskCount: 4, completedTaskCount: 1) == "3 tarefas faltam")
        #expect(missionBannerRemainingText(remaining: 1) == "1 tarefa para abrir o baú")
        #expect(missionsHeroSummaryText(inProgress: 1, completed: 1) == "1 em andamento · 1 concluída")
        #expect(missionsHeroSummaryText(inProgress: 2, completed: 3) == "2 em andamento · 3 concluídas")
        #expect(missionsHeroKidsSummaryText(completed: 1) == "Vocês já concluíram 1 missão juntos!")
    }

    @Test("Card footer: remaining tasks while in progress, reward situation once completed")
    func cardFooter() {
        let viewModel = makeViewModel(MissionRepositorySpy())
        let inProgress = makeSummary(title: "A", status: .inProgress, taskCount: 4, completedTaskCount: 1)
        let completed = makeSummary(title: "B", status: .completed, isRedemptionAvailable: true)

        #expect(viewModel.footerText(for: inProgress) == missionTasksRemainingText(taskCount: 4, completedTaskCount: 1))
        #expect(viewModel.footerText(for: completed) == String(localized: "mission.reward.available"))
    }

    @Test("Chest: closed in progress, ready when completed without reward, open once a reward is accepted")
    func chestStates() {
        let viewModel = makeViewModel(MissionRepositorySpy())
        #expect(viewModel.chestState(for: makeSummary(title: "A", status: .inProgress)) == .closed)
        #expect(viewModel.chestState(for: makeSummary(title: "B", status: .completed, isRedemptionAvailable: true)) == .ready)
        #expect(viewModel.chestState(for: makeSummary(
            title: "C", status: .completed, isRedemptionAvailable: false,
            acceptedReward: AcceptedMissionReward(rewardItemID: UUID(), title: "Noite de pizza")
        )) == .open)
    }
}
