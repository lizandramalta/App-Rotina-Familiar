import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-007 Mobile CAs for TEL-013: CA-01, CA-04, CA-10 to CA-14, CA-16.
@MainActor
struct TaskEditorViewModelTests {
    private let fixedToday = Date(timeIntervalSince1970: 1_760_000_000) // 2025-10-09T08:53:20Z

    private func makeViewModel(
        mode: TaskEditorMode = .create,
        repository: TaskRepositorySpy = TaskRepositorySpy(),
        members: [FamilyMember] = []
    ) -> TaskEditorViewModel {
        TaskEditorViewModel(
            mode: mode,
            repository: repository,
            familyRepository: FamilyMembersStub(members: members),
            accessToken: "access-1",
            today: { self.fixedToday }
        )
    }

    private func awaitingConfirmationFixture() -> FamilyTask {
        let task = TaskRepositorySpy.fixture
        return FamilyTask(
            id: task.id, title: task.title, weight: task.weight, scheduledDate: task.scheduledDate,
            assigneeIDs: task.assigneeIDs, note: task.note, status: .awaitingConfirmation,
            routineID: task.routineID, createdAt: task.createdAt
        )
    }

    @Test("CA-01 creates a task with the typed fields and stores the canonical result")
    func createSuccess() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Arrumar os brinquedos"
        viewModel.weight = .medium
        viewModel.note = "Guardar no baú"

        await viewModel.saveIfValid()

        let calls = repository.createCalls
        #expect(calls.count == 1)
        #expect(calls.first?.title == "Arrumar os brinquedos")
        #expect(calls.first?.weight == .medium)
        #expect(calls.first?.note == "Guardar no baú")
        #expect(viewModel.savedTask != nil)
    }

    @Test("CA-04 blocks save and reports a field error for an empty title, without calling the repository")
    func emptyTitleBlocksSave() async {
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = ""
        viewModel.weight = .low

        await viewModel.saveIfValid()

        #expect(viewModel.titleError == .required)
        let calls = repository.createCalls
        #expect(calls.isEmpty)
    }

    @Test("isFormValid requires both a non-empty title and a chosen weight")
    func formValidity() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isFormValid)

        viewModel.title = "Lavar a louça"
        #expect(!viewModel.isFormValid)

        viewModel.weight = .high
        #expect(viewModel.isFormValid)
    }

    @Test("Loading an existing task in edit mode pre-fills every field")
    func loadPrefillsFields() async {
        let task = FamilyTask(
            id: UUID(),
            title: "Guardar a roupa",
            weight: .high,
            scheduledDate: "2026-10-09",
            assigneeIDs: [UUID()],
            note: "Separar por cor",
            status: .pending,
            routineID: nil,
            createdAt: Date()
        )
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(mode: .edit(task.id), repository: repository)

        await viewModel.load()

        #expect(viewModel.title == "Guardar a roupa")
        #expect(viewModel.weight == .high)
        #expect(viewModel.note == "Separar por cor")
        #expect(viewModel.assigneeIDs == Set(task.assigneeIDs))
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("CA-10 forwards the picker's assignee set verbatim to the save command")
    func assigneesAreForwarded() async {
        let memberA = UUID()
        let memberB = UUID()
        let repository = TaskRepositorySpy()
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Tarefa com responsáveis"
        viewModel.weight = .low
        viewModel.setAssignees([memberA, memberB])

        await viewModel.saveIfValid()

        let calls = repository.createCalls
        #expect(Set(calls.first?.assigneeIDs ?? []) == [memberA, memberB])
    }

    @Test("CA-11 a network failure preserves every typed field and reports a banner instead of clearing the draft")
    func networkFailurePreservesDraft() async {
        let repository = TaskRepositorySpy(createResult: .failure(TaskError.network))
        let viewModel = makeViewModel(repository: repository)
        viewModel.title = "Organizar a sala"
        viewModel.weight = .medium
        viewModel.note = "Rascunho"

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .networkFailure)
        #expect(viewModel.title == "Organizar a sala")
        #expect(viewModel.weight == .medium)
        #expect(viewModel.note == "Rascunho")
        #expect(viewModel.savedTask == nil)
    }

    @Test("CA-07 a mission-protected edit reports a banner without discarding the draft")
    func missionProtectedEditPreservesDraft() async {
        let task = TaskRepositorySpy.fixture
        let repository = TaskRepositorySpy(
            taskResult: .success(task),
            updateResult: .failure(TaskError.missionCompletedProtected)
        )
        let viewModel = makeViewModel(mode: .edit(task.id), repository: repository)
        await viewModel.load()
        viewModel.title = "Novo título"

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .missionProtected)
        #expect(viewModel.title == "Novo título")
    }

    @Test("CA-14 editing an awaitingConfirmation task opens MOD-014 before saving, blocking on no choice")
    func awaitingConfirmationRequiresSignalResolution() async {
        let task = awaitingConfirmationFixture()
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(mode: .edit(task.id), repository: repository)
        await viewModel.load()
        viewModel.note = "Observação atualizada"

        await viewModel.saveIfValid()

        #expect(viewModel.isSignalResolutionPresented)
        let callsBeforeChoice = repository.updateCalls
        #expect(callsBeforeChoice.isEmpty)
    }

    @Test("CA-12 choosing resetToPending sends it in the update command and saves")
    func signalResolutionResetToPending() async {
        let task = awaitingConfirmationFixture()
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(mode: .edit(task.id), repository: repository)
        await viewModel.load()

        await viewModel.saveIfValid()
        viewModel.chooseSignalResolution(.resetToPending)
        await viewModel.confirmSignalResolutionAndSave()

        let calls = repository.updateCalls
        #expect(calls.first?.signalResolution == .resetToPending)
    }

    @Test("CA-13 choosing keepAwaitingConfirmation saves even when only the note changed")
    func signalResolutionKeepAwaitingConfirmation() async {
        let task = awaitingConfirmationFixture()
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let viewModel = makeViewModel(mode: .edit(task.id), repository: repository)
        await viewModel.load()
        viewModel.note = "Só a observação mudou"

        await viewModel.saveIfValid()
        viewModel.chooseSignalResolution(.keepAwaitingConfirmation)
        await viewModel.confirmSignalResolutionAndSave()

        let calls = repository.updateCalls
        #expect(calls.first?.signalResolution == .keepAwaitingConfirmation)
        #expect(calls.first?.note == "Só a observação mudou")
    }
}
