import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MissionDetailViewModelTests {
    private static let adultMemberID = UUID()
    private static let kidMemberID = UUID()

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

    @Test("Hydrates every linked task by id since the mission resource only carries bare taskIds")
    func loadsAndHydratesLinkedTasks() async {
        let taskID = UUID()
        let repository = MissionRepositorySpy(missionResult: .success(Mission(
            id: MissionRepositorySpy.fixture.id,
            familyID: MissionRepositorySpy.fixture.familyID,
            title: "Casa pronta para o fim de semana",
            note: "Antes da visita da vó",
            status: .inProgress,
            taskIDs: [taskID],
            completedAt: nil,
            isRedemptionAvailable: false,
            createdAt: Date()
        )))
        let taskRepository = TaskRepositorySpy(taskResult: .success(makeFamilyTask(id: taskID)))
        let viewModel = MissionDetailViewModel(
            missionID: MissionRepositorySpy.fixture.id,
            role: .administrator,
            currentMemberID: Self.adultMemberID,
            repository: repository,
            taskRepository: taskRepository,
            accessToken: "token"
        )

        await viewModel.load()

        #expect(viewModel.mission?.title == "Casa pronta para o fim de semana")
        #expect(viewModel.linkedTasks.map(\.id) == [taskID])
        #expect(!viewModel.loadFailed)
    }

    @Test("A hydration failure fails the whole screen instead of showing a partial task list")
    func hydrationFailureFailsWholeScreen() async {
        let repository = MissionRepositorySpy(missionResult: .success(Mission(
            id: MissionRepositorySpy.fixture.id,
            familyID: MissionRepositorySpy.fixture.familyID,
            title: "Casa pronta para o fim de semana",
            note: nil,
            status: .inProgress,
            taskIDs: [UUID()],
            completedAt: nil,
            isRedemptionAvailable: false,
            createdAt: Date()
        )))
        let taskRepository = TaskRepositorySpy(taskResult: .failure(TaskError.notFound))
        let viewModel = MissionDetailViewModel(
            missionID: MissionRepositorySpy.fixture.id,
            role: .administrator,
            currentMemberID: Self.adultMemberID,
            repository: repository,
            taskRepository: taskRepository,
            accessToken: "token"
        )

        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.mission == nil)
        #expect(viewModel.linkedTasks.isEmpty)
    }

    @Test("CA-19 Kids decode a mission missing isRedemptionAvailable without throwing, and never see Editar")
    func kidsSimplifiedProjection() async {
        let repository = MissionRepositorySpy(missionResult: .success(Mission(
            id: MissionRepositorySpy.fixture.id,
            familyID: MissionRepositorySpy.fixture.familyID,
            title: "Casa pronta para o fim de semana",
            note: nil,
            status: .inProgress,
            taskIDs: [],
            completedAt: nil,
            isRedemptionAvailable: nil,
            createdAt: Date()
        )))
        let viewModel = MissionDetailViewModel(
            missionID: MissionRepositorySpy.fixture.id,
            role: .kid,
            currentMemberID: Self.kidMemberID,
            repository: repository,
            taskRepository: TaskRepositorySpy(),
            accessToken: "token"
        )

        await viewModel.load()

        #expect(viewModel.mission?.isRedemptionAvailable == nil)
        #expect(!viewModel.canEdit)
    }

    @Test("Admin can edit only while the mission is in progress")
    func canEditOnlyAdminAndInProgress() async {
        let completedMission = Mission(
            id: MissionRepositorySpy.fixture.id,
            familyID: MissionRepositorySpy.fixture.familyID,
            title: "Semana organizada",
            note: nil,
            status: .completed,
            taskIDs: [],
            completedAt: Date(),
            isRedemptionAvailable: true,
            createdAt: Date()
        )
        let viewModel = MissionDetailViewModel(
            missionID: MissionRepositorySpy.fixture.id,
            role: .administrator,
            currentMemberID: Self.adultMemberID,
            repository: MissionRepositorySpy(missionResult: .success(completedMission)),
            taskRepository: TaskRepositorySpy(),
            accessToken: "token"
        )

        await viewModel.load()

        #expect(!viewModel.canEdit)
    }

    @Test("Kids only open their own linked tasks, never someone else's")
    func kidsOnlyOpenOwnTasks() {
        let viewModel = MissionDetailViewModel(
            missionID: UUID(),
            role: .kid,
            currentMemberID: Self.kidMemberID,
            repository: MissionRepositorySpy(),
            taskRepository: TaskRepositorySpy(),
            accessToken: "token"
        )

        let ownTask = MissionTaskOption(id: UUID(), title: "Trocar a roupa de cama", weight: .low, scheduledDate: "2026-10-10", status: .pending, assigneeIDs: [Self.kidMemberID])
        let otherTask = MissionTaskOption(id: UUID(), title: "Faxina da sala", weight: .low, scheduledDate: "2026-10-10", status: .pending, assigneeIDs: [Self.adultMemberID])

        #expect(viewModel.canOpenTaskDetail(ownTask))
        #expect(!viewModel.canOpenTaskDetail(otherTask))
    }

    @Test("Adults and members can open any linked task")
    func adultsOpenAnyTask() {
        let viewModel = MissionDetailViewModel(
            missionID: UUID(),
            role: .administrator,
            currentMemberID: Self.adultMemberID,
            repository: MissionRepositorySpy(),
            taskRepository: TaskRepositorySpy(),
            accessToken: "token"
        )

        let otherTask = MissionTaskOption(id: UUID(), title: "Faxina da sala", weight: .low, scheduledDate: "2026-10-10", status: .pending, assigneeIDs: [Self.kidMemberID])

        #expect(viewModel.canOpenTaskDetail(otherTask))
    }
}
