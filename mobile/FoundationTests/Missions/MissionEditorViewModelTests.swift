import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MissionEditorViewModelTests {
    private func makeTaskOption(id: UUID = UUID(), title: String = "Arrumar o quintal") -> MissionTaskOption {
        MissionTaskOption(id: id, title: title, weight: .medium, scheduledDate: "2026-10-10", status: .pending, assigneeIDs: [])
    }

    private func makeViewModel(
        mode: MissionEditorMode = .create,
        repository: MissionRepositorySpy = MissionRepositorySpy(),
        taskRepository: TaskRepositorySpy = TaskRepositorySpy()
    ) -> MissionEditorViewModel {
        MissionEditorViewModel(mode: mode, repository: repository, taskRepository: taskRepository, accessToken: "token")
    }

    @Test("CA-12 keeps Salvar disabled, shows the inline reason, and never calls the backend without a linked task")
    func blocksSaveWithoutTasks() async {
        let repository = MissionRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Arrumar o quintal"

        #expect(!viewModel.isFormValid)
        #expect(viewModel.showsTasksRequiredError)

        await viewModel.saveIfValid()

        #expect(repository.createCalls.isEmpty)
        #expect(viewModel.savedMission == nil)
    }

    @Test("Creates a mission with the typed title, note and linked tasks")
    func createSuccess() async {
        let repository = MissionRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        let task = makeTaskOption()
        viewModel.title = "Arrumar o quintal"
        viewModel.note = "Antes do churrasco"
        viewModel.applyPickerSelection([task])

        #expect(viewModel.isFormValid)
        await viewModel.saveIfValid()

        #expect(repository.createCalls.count == 1)
        #expect(repository.createCalls.first?.title == "Arrumar o quintal")
        #expect(repository.createCalls.first?.note == "Antes do churrasco")
        #expect(repository.createCalls.first?.taskIDs == [task.id])
        #expect(viewModel.savedMission != nil)
    }

    @Test("CA-09 edits an in-progress mission's title, note and linked tasks")
    func editSuccess() async {
        let missionID = MissionRepositorySpy.fixture.id
        let existingTaskID = UUID()
        let repository = MissionRepositorySpy(missionResult: .success(Mission(
            id: missionID,
            familyID: MissionRepositorySpy.fixture.familyID,
            title: "Roupa em dia",
            note: nil,
            status: .inProgress,
            taskIDs: [existingTaskID],
            completedAt: nil,
            isRedemptionAvailable: false,
            createdAt: MissionRepositorySpy.fixture.createdAt
        )))
        let taskRepository = TaskRepositorySpy(taskResult: .success(FamilyTask(
            id: existingTaskID,
            title: "Lavar a louça",
            weight: .low,
            scheduledDate: "2026-10-08",
            assigneeIDs: [],
            note: nil,
            status: .pending,
            routineID: nil,
            createdAt: Date()
        )))
        let viewModel = makeViewModel(mode: .edit(missionID), repository: repository, taskRepository: taskRepository)
        await viewModel.load()

        #expect(viewModel.title == "Roupa em dia")
        #expect(viewModel.linkedTasks.map(\.id) == [existingTaskID])
        #expect(!viewModel.hasUnsavedChanges)

        viewModel.title = "Roupa em dia (revisado)"
        #expect(viewModel.hasUnsavedChanges)

        await viewModel.saveIfValid()

        #expect(repository.updateCalls.count == 1)
        #expect(repository.updateCalls.first?.title == "Roupa em dia (revisado)")
        #expect(viewModel.savedMission != nil)
    }

    @Test("Draft fields are preserved and a banner is shown when the save fails")
    func savePreservesDraftOnFailure() async {
        // The network->uncertain translation on create happens in `HTTPMissionRepository` itself
        // (covered by `HTTPMissionRepositoryTests.createMissionNetworkFailureIsUncertain`); a bare
        // repository double throwing `.network` reaches the view model as `.network` verbatim.
        let repository = MissionRepositorySpy(createResult: .failure(MissionError.network))
        let viewModel = makeViewModel(repository: repository)
        let task = makeTaskOption()
        viewModel.title = "Arrumar o quintal"
        viewModel.applyPickerSelection([task])

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .networkFailure)
        #expect(viewModel.title == "Arrumar o quintal")
        #expect(viewModel.linkedTasks.map(\.id) == [task.id])
    }

    @Test("409 MISSION_COMPLETED_PROTECTED maps to the completedProtected banner")
    func completedProtectedBanner() async {
        let repository = MissionRepositorySpy(updateResult: .failure(MissionError.completedProtected))
        let viewModel = makeViewModel(mode: .edit(UUID()), repository: repository)
        let task = makeTaskOption()
        viewModel.title = "Arrumar o quintal"
        viewModel.applyPickerSelection([task])

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .completedProtected)
    }

    @Test("Applying the picker's selection updates the linked-tasks draft and recomputes validity")
    func applyPickerSelectionUpdatesDraft() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isFormValid)

        let task = makeTaskOption()
        viewModel.applyPickerSelection([task])
        viewModel.title = "Arrumar o quintal"

        #expect(viewModel.linkedTasks.map(\.id) == [task.id])
        #expect(viewModel.isFormValid)

        viewModel.applyPickerSelection([])
        #expect(!viewModel.isFormValid)
        #expect(viewModel.showsTasksRequiredError)
    }
}
