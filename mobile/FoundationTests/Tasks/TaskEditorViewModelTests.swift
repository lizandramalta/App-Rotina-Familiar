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
        routineRepository: RoutineRepositorySpy = RoutineRepositorySpy(),
        members: [FamilyMember] = []
    ) -> TaskEditorViewModel {
        TaskEditorViewModel(
            mode: mode,
            repository: repository,
            routineRepository: routineRepository,
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

    @Test("SPEC-008 CA-01/CA-02: selecting recurrence sends the routine contract and never creates a single task")
    func createsRoutineWithSelectedFrequency() async {
        let taskRepository = TaskRepositorySpy()
        let routineRepository = RoutineRepositorySpy()
        let viewModel = makeViewModel(repository: taskRepository, routineRepository: routineRepository)
        viewModel.title = "Regar as plantas"
        viewModel.weight = .low
        viewModel.note = "Antes do almoço"
        let memberID = UUID()
        viewModel.setAssignees([memberID])

        await viewModel.prepareRecurrencePicker()
        #expect(viewModel.isRecurrencePickerPresented)
        viewModel.setRecurrence(startDate: viewModel.scheduledDate, frequency: .everySevenDays)
        await viewModel.saveIfValid()

        let command = routineRepository.createCalls.first
        #expect(routineRepository.createCalls.count == 1)
        #expect(taskRepository.createCalls.isEmpty)
        #expect(command?.title == "Regar as plantas")
        #expect(command?.note == "Antes do almoço")
        #expect(command?.frequency == .everySevenDays)
        #expect(command?.assigneeIDs == [memberID])
        #expect(viewModel.savedRoutine?.materializationState == .pending)
    }

    @Test("SPEC-008 §5.3: a lost create response preserves the routine draft without automatic replay")
    func uncertainRoutineCreationPreservesDraft() async {
        let routineRepository = RoutineRepositorySpy(createResult: .failure(RoutineError.uncertainOutcome))
        let viewModel = makeViewModel(routineRepository: routineRepository)
        viewModel.title = "Regar as plantas"
        viewModel.weight = .low
        await viewModel.prepareRecurrencePicker()
        viewModel.setRecurrence(startDate: viewModel.scheduledDate, frequency: .daily)

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .routineUncertainOutcome)
        #expect(viewModel.title == "Regar as plantas")
        #expect(viewModel.frequency == .daily)
        #expect(viewModel.savedRoutine == nil)
        #expect(routineRepository.createCalls.count == 1)
    }

    @Test("SPEC-008 CA-02: backend frequency and start-date errors stay attached to the saved draft")
    func routineValidationErrorsAreVisible() async {
        let routineRepository = RoutineRepositorySpy(createResult: .failure(
            RoutineError.validationFailed([
                "frequencyDays": ["FREQUENCY_DAYS_INVALID"],
                "startDate": ["START_DATE_INVALID"]
            ])
        ))
        let viewModel = makeViewModel(routineRepository: routineRepository)
        viewModel.title = "Regar as plantas"
        viewModel.weight = .low
        await viewModel.prepareRecurrencePicker()
        viewModel.setRecurrence(startDate: viewModel.scheduledDate, frequency: .daily)

        await viewModel.saveIfValid()

        #expect(viewModel.frequencyError)
        #expect(viewModel.startDateError)
        #expect(viewModel.hasUnsavedChanges)
    }

    @Test("SPEC-008 RN11: MOD-002 uses the family's civil day when no date was edited")
    func recurrenceDefaultsToFamilyToday() async {
        let now = ISO8601DateFormatter().date(from: "2026-10-10T01:00:00Z")!
        let viewModel = TaskEditorViewModel(
            mode: .create,
            repository: TaskRepositorySpy(),
            routineRepository: RoutineRepositorySpy(),
            familyRepository: FamilyMembersStub(),
            accessToken: "access-1",
            today: { now }
        )

        await viewModel.prepareRecurrencePicker()

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        #expect(formatter.string(from: viewModel.scheduledDate) == "2026-10-09")
        #expect(!viewModel.hasUnsavedChanges)
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

    private func routineOccurrenceFixture(status: TaskStatus = .pending) -> FamilyTask {
        let task = TaskRepositorySpy.fixture
        return FamilyTask(
            id: task.id, title: task.title, weight: task.weight, scheduledDate: task.scheduledDate,
            assigneeIDs: task.assigneeIDs, note: task.note, status: status,
            routineID: routineRepositorySpyFixture.id, createdAt: task.createdAt
        )
    }

    @Test("SPEC-008 CA-07 / E-05 to E-08: \"Esta tarefa e as futuras\" saves through the routine, date locked, no MOD-014")
    func savesThisAndFutureThroughRoutine() async {
        let task = routineOccurrenceFixture(status: .awaitingConfirmation)
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let routineRepository = RoutineRepositorySpy()
        let viewModel = makeViewModel(mode: .edit(task.id, scope: .thisAndFuture), repository: repository, routineRepository: routineRepository)
        await viewModel.load()
        viewModel.title = "Arrumar os brinquedos da sala"

        #expect(viewModel.isScheduledDateLocked)
        #expect(viewModel.editingRecurrenceSummary == String(format: String(localized: "routines.recurrence.every_days"), 7))
        await viewModel.saveIfValid()

        #expect(viewModel.isSignalResolutionPresented == false)
        #expect(repository.updateCalls.isEmpty)
        let call = routineRepository.updateFutureCalls.first
        #expect(call?.routineID == routineRepositorySpyFixture.id)
        #expect(call?.command.fromTaskID == task.id)
        #expect(call?.command.title == "Arrumar os brinquedos da sala")
        #expect(viewModel.savedTask?.scheduledDate == task.scheduledDate)
        #expect(viewModel.savedTask?.status == .awaitingConfirmation)
    }

    @Test("SPEC-008 UX-04: \"Somente esta tarefa\" keeps the individual edit with an editable date")
    func savesOnlyThisIndividually() async {
        let task = routineOccurrenceFixture()
        let repository = TaskRepositorySpy(taskResult: .success(task))
        let routineRepository = RoutineRepositorySpy()
        let viewModel = makeViewModel(mode: .edit(task.id, scope: .onlyThis), repository: repository, routineRepository: routineRepository)
        await viewModel.load()

        #expect(viewModel.isScheduledDateLocked == false)
        await viewModel.saveIfValid()

        #expect(repository.updateCalls.count == 1)
        #expect(routineRepository.updateFutureCalls.isEmpty)
    }

    @Test("SPEC-008 E-10: a protected source keeps the draft and explains the block")
    func protectedSourceKeepsDraft() async {
        let task = routineOccurrenceFixture()
        let routineRepository = RoutineRepositorySpy(updateFutureResult: .failure(RoutineError.missionProtected))
        let viewModel = makeViewModel(
            mode: .edit(task.id, scope: .thisAndFuture),
            repository: TaskRepositorySpy(taskResult: .success(task)),
            routineRepository: routineRepository
        )
        await viewModel.load()
        viewModel.title = "Novo título"

        await viewModel.saveIfValid()

        #expect(viewModel.banner == .missionProtected)
        #expect(viewModel.savedTask == nil)
        #expect(viewModel.title == "Novo título")
    }

    @Test("Figma MOD-001: the signed-in member is listed first as \"Você\"")
    func currentMemberFirstAsYou() async {
        let me = UUID()
        let other = FamilyMember(id: UUID(), name: "Alex", role: .member, isFamilyCreator: false)
        let viewModel = TaskEditorViewModel(
            mode: .create,
            repository: TaskRepositorySpy(),
            routineRepository: RoutineRepositorySpy(),
            familyRepository: FamilyMembersStub(members: [other, FamilyMember(id: me, name: "Maria", role: .administrator, isFamilyCreator: true)]),
            accessToken: "access-1",
            currentMemberID: me,
            today: { self.fixedToday }
        )
        await viewModel.loadAssigneeCandidatesIfNeeded()

        #expect(viewModel.orderedMembers.first?.id == me)
        #expect(viewModel.displayName(for: viewModel.orderedMembers[0]) == String(localized: "tasks.detail.you"))
        #expect(viewModel.displayName(for: other) == "Alex")
    }
}

