import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-016 Fase 2 (SCRUM-86) — TEL-021 detail behaviour: CA-03/05/06 presentation, CA-07 recovery.
@MainActor
struct MissionDetailViewModelTests {
    private static let adultMemberID = UUID()
    private static let kidMemberID = UUID()
    private static let pizza = AcceptedMissionReward(rewardItemID: UUID(), title: "Noite de pizza")
    private static let participations = [
        MissionParticipation(memberID: adultMemberID, displayName: "Ana Silva"),
        MissionParticipation(memberID: kidMemberID, displayName: "Rafa Silva"),
    ]

    private func makeFamilyTask(id: UUID, assigneeIDs: [UUID] = []) -> FamilyTask {
        FamilyTask(
            id: id,
            title: "Faxina da sala",
            weight: .medium,
            scheduledDate: "2026-10-10",
            assigneeIDs: assigneeIDs,
            note: nil,
            status: .pending,
            routineID: nil,
            createdAt: Date()
        )
    }

    private func makeViewModel(
        role: MemberRole,
        repository: MissionRepositorySpy,
        taskRepository: TaskRepositorySpy = TaskRepositorySpy()
    ) -> MissionDetailViewModel {
        MissionDetailViewModel(
            missionID: MissionRepositorySpy.fixture.id,
            role: role,
            currentMemberID: role == .kid ? Self.kidMemberID : Self.adultMemberID,
            repository: repository,
            taskRepository: taskRepository,
            accessToken: "token"
        )
    }

    @Test("Adults render linked tasks from the projection and can open any of them")
    func adultsUseProjectionTasks() async {
        let task = MissionLinkedTask(id: UUID(), title: "Guardar a roupa", status: .awaitingConfirmation)
        let repository = MissionRepositorySpy(missionResult: .success(makeMissionDetail(note: "Antes da visita", tasks: [task])))
        let viewModel = makeViewModel(role: .administrator, repository: repository)

        await viewModel.load()

        #expect(viewModel.mission?.tasks == [task])
        #expect(viewModel.mission?.note == "Antes da visita")
        #expect(viewModel.canOpenTaskDetail(task))
    }

    @Test("E-1 (Figma 579-59): adults also get the 'SUA TAREFA' balloon on their own linked task")
    func adultsOwnTaskBalloon() async {
        let ownTaskID = UUID()
        let ownTask = MissionLinkedTask(id: ownTaskID, title: "Arrumar o quarto", status: .pending)
        let otherTask = MissionLinkedTask(id: UUID(), title: "Faxina da sala", status: .pending)
        let repository = MissionRepositorySpy(missionResult: .success(makeMissionDetail(tasks: [ownTask, otherTask])))
        let taskRepository = TaskRepositorySpy(taskResult: .success(makeFamilyTask(id: ownTaskID, assigneeIDs: [Self.adultMemberID])))
        let viewModel = makeViewModel(role: .member, repository: repository, taskRepository: taskRepository)

        await viewModel.load()

        #expect(viewModel.isOwnTask(ownTask))
        #expect(!viewModel.isOwnTask(otherTask))
        #expect(viewModel.canOpenTaskDetail(otherTask))
    }

    @Test("E-1: an adult ownership lookup failure only drops the balloon — every task stays openable")
    func adultOwnershipFailureKeepsNavigation() async {
        let task = MissionLinkedTask(id: UUID(), title: "Arrumar o quarto", status: .pending)
        let repository = MissionRepositorySpy(missionResult: .success(makeMissionDetail(tasks: [task])))
        let viewModel = makeViewModel(role: .administrator, repository: repository, taskRepository: TaskRepositorySpy(taskResult: .failure(TaskError.network)))

        await viewModel.load()

        #expect(!viewModel.loadFailed)
        #expect(!viewModel.isOwnTask(task))
        #expect(viewModel.canOpenTaskDetail(task))
    }

    @Test("Banner says how many tasks open the chest, or 'Missão concluída!' once completed")
    func bannerSubtitle() async {
        let inProgress = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(makeMissionDetail(tasks: [
            MissionLinkedTask(id: UUID(), title: "A", status: .completed),
            MissionLinkedTask(id: UUID(), title: "B", status: .pending),
            MissionLinkedTask(id: UUID(), title: "C", status: .awaitingConfirmation),
        ]))))
        await inProgress.load()
        #expect(inProgress.bannerSubtitle == missionBannerRemainingText(remaining: 2))
        #expect(inProgress.chestState == .closed)

        let completed = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(status: .completed, progressPercent: 100, isRedemptionAvailable: false, acceptedReward: Self.pizza)
        )))
        await completed.load()
        #expect(completed.bannerSubtitle == String(localized: "mission.banner.completed"))
        #expect(completed.chestState == .open)
    }

    @Test("CA-02: awaitingConfirmation never counts as completed in the detail's fraction")
    func awaitingConfirmationNotCompleted() async {
        let detail = makeMissionDetail(tasks: [
            MissionLinkedTask(id: UUID(), title: "A", status: .completed),
            MissionLinkedTask(id: UUID(), title: "B", status: .awaitingConfirmation),
        ], progressPercent: 50)
        let viewModel = makeViewModel(role: .member, repository: MissionRepositorySpy(missionResult: .success(detail)))

        await viewModel.load()

        #expect(viewModel.mission?.completedTaskCount == 1)
        #expect(viewModel.mission?.status == .inProgress)
    }

    @Test("CA-03: Admin and Member see the accepted reward and the participations")
    func adultsSeeRewardAndParticipations() async {
        for role in [MemberRole.administrator, .member] {
            let detail = makeMissionDetail(
                status: .completed, progressPercent: 100, isRedemptionAvailable: false,
                acceptedReward: Self.pizza, participations: Self.participations
            )
            let viewModel = makeViewModel(role: role, repository: MissionRepositorySpy(missionResult: .success(detail)))

            await viewModel.load()

            #expect(viewModel.rewardState == .accepted(title: "Noite de pizza"))
            #expect(viewModel.participations == Self.participations)
        }
    }

    @Test("CA-03: Kids see the accepted reward but never the participations block, nor Editar")
    func kidsSeeRewardWithoutParticipations() async {
        let detail = makeMissionDetail(
            status: .completed, progressPercent: 100, isRedemptionAvailable: nil,
            acceptedReward: Self.pizza, participations: nil
        )
        let viewModel = makeViewModel(role: .kid, repository: MissionRepositorySpy(missionResult: .success(detail)))

        await viewModel.load()

        #expect(viewModel.rewardState == .accepted(title: "Noite de pizza"))
        #expect(viewModel.participations == nil)
        #expect(!viewModel.canEdit)
    }

    @Test("CA-03: Kids never get a participations block even if a payload carried the field")
    func kidsIgnoreUnexpectedParticipations() async {
        let detail = makeMissionDetail(status: .completed, isRedemptionAvailable: nil, participations: Self.participations)
        let viewModel = makeViewModel(role: .kid, repository: MissionRepositorySpy(missionResult: .success(detail)))

        await viewModel.load()

        #expect(viewModel.participations == nil)
    }

    @Test("CA-05: true redemption situation — in progress, completed without acceptance (adult / Kids)")
    func rewardSituationWithoutAcceptance() async {
        let inProgress = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(makeMissionDetail())))
        await inProgress.load()
        #expect(inProgress.rewardState == MissionRewardState.none)

        let completedAdult = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(status: .completed, progressPercent: 100, isRedemptionAvailable: true)
        )))
        await completedAdult.load()
        #expect(completedAdult.rewardState == .redemptionAvailable)

        let completedKids = makeViewModel(role: .kid, repository: MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(status: .completed, progressPercent: 100, isRedemptionAvailable: nil, participations: nil)
        )))
        await completedKids.load()
        #expect(completedKids.rewardState == MissionRewardState.none)
    }

    @Test("An in-progress mission shows no participations block (none exist yet, SPEC-016 §6)")
    func inProgressHasNoParticipations() async {
        let viewModel = makeViewModel(role: .member, repository: MissionRepositorySpy(missionResult: .success(makeMissionDetail())))

        await viewModel.load()

        #expect(viewModel.participations == nil)
    }

    @Test("CA-06: after a confirmed reopening the refreshed detail drops reward and participations")
    func reopeningIsReflectedOnRefresh() async {
        let repository = MissionRepositorySpy(missionResult: .success(makeMissionDetail(
            status: .completed, progressPercent: 100, isRedemptionAvailable: false,
            acceptedReward: Self.pizza, participations: Self.participations
        )))
        let viewModel = makeViewModel(role: .administrator, repository: repository)
        await viewModel.load()

        repository.setMissionResult(.success(makeMissionDetail(status: .inProgress, progressPercent: 50)))
        await viewModel.load()

        #expect(viewModel.mission?.status == .inProgress)
        #expect(viewModel.rewardState == MissionRewardState.none)
        #expect(viewModel.participations == nil)
    }

    @Test("CA-07: an initial failure is a full-screen recoverable error; retry loads the detail")
    func initialFailureThenRetry() async {
        let repository = MissionRepositorySpy(missionResult: .failure(MissionError.network))
        let viewModel = makeViewModel(role: .administrator, repository: repository)

        await viewModel.load()
        #expect(viewModel.loadFailed)
        #expect(viewModel.mission == nil)

        repository.setMissionResult(.success(makeMissionDetail()))
        await viewModel.load()
        #expect(!viewModel.loadFailed)
        #expect(viewModel.mission != nil)
    }

    @Test("CA-07: a failed refresh keeps the confirmed detail and raises the non-blocking banner")
    func refreshFailureKeepsConfirmedDetail() async {
        let confirmed = makeMissionDetail(status: .completed, progressPercent: 100, isRedemptionAvailable: true)
        let repository = MissionRepositorySpy(missionResult: .success(confirmed))
        let viewModel = makeViewModel(role: .administrator, repository: repository)
        await viewModel.load()

        repository.setMissionResult(.failure(MissionError.unavailable))
        await viewModel.load()

        #expect(viewModel.mission == confirmed)
        #expect(viewModel.refreshFailed)
        #expect(!viewModel.loadFailed)
    }

    @Test("Admin can edit only while the mission is in progress")
    func canEditOnlyAdminAndInProgress() async {
        let completed = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(status: .completed, progressPercent: 100, isRedemptionAvailable: true)
        )))
        await completed.load()
        #expect(!completed.canEdit)

        let inProgress = makeViewModel(role: .administrator, repository: MissionRepositorySpy(missionResult: .success(makeMissionDetail())))
        await inProgress.load()
        #expect(inProgress.canEdit)

        let member = makeViewModel(role: .member, repository: MissionRepositorySpy(missionResult: .success(makeMissionDetail())))
        await member.load()
        #expect(!member.canEdit)
    }

    @Test("E-1: Kids only open their own linked tasks, never someone else's")
    func kidsOnlyOpenOwnTasks() async {
        let ownTaskID = UUID()
        let ownTask = MissionLinkedTask(id: ownTaskID, title: "Trocar a roupa de cama", status: .pending)
        let otherTask = MissionLinkedTask(id: UUID(), title: "Faxina da sala", status: .pending)
        let repository = MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(tasks: [ownTask, otherTask], isRedemptionAvailable: nil, participations: nil)
        ))
        // The spy answers every lookup with the Kids-owned task, so only `ownTaskID` resolves as own.
        let taskRepository = TaskRepositorySpy(taskResult: .success(makeFamilyTask(id: ownTaskID, assigneeIDs: [Self.kidMemberID])))
        let viewModel = makeViewModel(role: .kid, repository: repository, taskRepository: taskRepository)

        await viewModel.load()

        #expect(viewModel.canOpenTaskDetail(ownTask))
        #expect(!viewModel.canOpenTaskDetail(otherTask))
    }

    @Test("E-1: if Kids ownership lookup fails, content stays visible and no row is tappable")
    func kidsOwnershipFailureIsConservative() async {
        let task = MissionLinkedTask(id: UUID(), title: "Trocar a roupa de cama", status: .pending)
        let repository = MissionRepositorySpy(missionResult: .success(
            makeMissionDetail(tasks: [task], isRedemptionAvailable: nil, participations: nil)
        ))
        let taskRepository = TaskRepositorySpy(taskResult: .failure(TaskError.network))
        let viewModel = makeViewModel(role: .kid, repository: repository, taskRepository: taskRepository)

        await viewModel.load()

        #expect(viewModel.mission?.tasks == [task])
        #expect(!viewModel.loadFailed)
        #expect(!viewModel.canOpenTaskDetail(task))
    }
}
