import Foundation
import Observation

enum TaskFieldError: Equatable {
    case required
    case invalid
}

/// Non-blocking feedback after a failed save (UX-007 §6 "Error não bloqueante").
enum TaskEditorBanner: Equatable {
    case networkFailure
    case uncertainOutcome
    case actionNotAllowed
    case missionProtected
    case rejected
    case routineUnavailable
    case routineUncertainOutcome
    /// `ROUTINE_SOURCE_TASK_INVALID` — the open occurrence can no longer define the scope.
    case routineSourceInvalid
}

enum TaskEditorMode: Equatable {
    case create
    /// `scope` is set only when editing a routine occurrence through MOD-003 (UX-008 §4).
    case edit(UUID, scope: RoutineScope? = nil)
}

/// Backs TEL-013 (single-task fields only — recurrence belongs to SPEC-008). Pushed, never a sheet.
@MainActor
@Observable
final class TaskEditorViewModel {
    private let mode: TaskEditorMode
    private let getTaskDetail: GetTaskDetailUseCase
    private let createTask: CreateTaskUseCase
    private let updateTask: UpdateTaskUseCase
    private let createRoutine: CreateRoutineUseCase
    private let getRoutine: GetRoutineUseCase
    private let updateFutureRoutine: UpdateFutureRoutineUseCase
    private let routineRepository: any RoutineRepository
    private let familyRepository: any FamilyRepository
    private let accessToken: String
    private let today: () -> Date
    /// Lets MOD-001 and the Quem faz summary show the signed-in member as "Você" (Figma MOD-001).
    let currentMemberID: UUID?

    var title = ""
    var weight: EffortWeight?
    var scheduledDate: Date
    var note = ""
    private(set) var assigneeIDs: Set<UUID> = []
    private(set) var frequency: RoutineFrequency?
    private(set) var familyTimeZoneID: String?
    var isRecurrencePickerPresented = false

    private(set) var titleError: TaskFieldError?
    private(set) var noteError: TaskFieldError?
    private(set) var startDateError = false
    private(set) var frequencyError = false

    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// Set once the existing task loads in edit mode; `nil` while creating or still loading.
    private(set) var currentStatus: TaskStatus?
    /// The occurrence being edited, kept to rebuild it after a routine-scope save.
    private var loadedTask: FamilyTask?
    /// The routine of the occurrence being edited, shown read-only in the Repetição row.
    private(set) var editingRoutine: Routine?

    private(set) var isSaving = false
    private(set) var banner: TaskEditorBanner?
    private(set) var savedTask: FamilyTask?
    private(set) var savedRoutine: Routine?

    var isAssigneePickerPresented = false
    var isSignalResolutionPresented = false
    private(set) var signalResolutionChoice: SignalResolution?

    private(set) var availableMembers: [FamilyMember] = []
    private(set) var isLoadingMembers = false
    private(set) var membersLoadFailed = false
    private var hasLoadedMembers = false

    private struct Snapshot: Equatable {
        let title: String
        let weight: EffortWeight?
        let scheduledDate: Date
        let note: String
        let assigneeIDs: Set<UUID>
        let frequency: RoutineFrequency?
    }
    private var initialSnapshot: Snapshot?

    init(
        mode: TaskEditorMode,
        repository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: any FamilyRepository,
        accessToken: String,
        currentMemberID: UUID? = nil,
        today: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.currentMemberID = currentMemberID
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.createTask = CreateTaskUseCase(repository: repository)
        self.updateTask = UpdateTaskUseCase(repository: repository)
        self.createRoutine = CreateRoutineUseCase(repository: routineRepository)
        self.getRoutine = GetRoutineUseCase(repository: routineRepository)
        self.updateFutureRoutine = UpdateFutureRoutineUseCase(repository: routineRepository)
        self.routineRepository = routineRepository
        self.familyRepository = familyRepository
        self.accessToken = accessToken
        self.today = today
        self.scheduledDate = today()
        if mode == .create {
            initialSnapshot = Snapshot(title: "", weight: nil, scheduledDate: self.scheduledDate, note: "", assigneeIDs: [], frequency: nil)
        }
    }

    /// Drives the "Descartar alterações?" confirmation when leaving TEL-013 (UX-007 §4).
    var hasUnsavedChanges: Bool {
        guard let initialSnapshot else {
            return false
        }
        let current = Snapshot(title: title, weight: weight, scheduledDate: scheduledDate, note: note, assigneeIDs: assigneeIDs, frequency: frequency)
        return current != initialSnapshot
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var routineScope: RoutineScope? {
        if case let .edit(_, scope) = mode { return scope }
        return nil
    }

    /// "Esta tarefa e as futuras" never moves occurrences: the date stays as generated (SPEC-008 E-07).
    var isScheduledDateLocked: Bool {
        routineScope == .thisAndFuture
    }

    /// Editing never turns a single task into a routine nor changes a routine's frequency (UX-008 UX-05).
    var editingRecurrenceSummary: String {
        guard let frequency = editingRoutine?.frequency else {
            return loadedTask?.routineID == nil ? String(localized: "routines.recurrence.none") : ""
        }
        return Self.summary(for: frequency)
    }

    /// The form only enables Salvar once title and weight are both valid (UX-007 §5.1).
    var isFormValid: Bool {
        guard case .success = TaskValidation.validatedTitle(title) else {
            return false
        }
        return weight != nil
    }

    func load() async {
        guard case let .edit(taskID, _) = mode else {
            return
        }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let task = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
            title = task.title
            weight = task.weight
            scheduledDate = Self.date(fromWire: task.scheduledDate) ?? today()
            note = task.note ?? ""
            assigneeIDs = Set(task.assigneeIDs)
            currentStatus = task.status
            loadedTask = task
            if let routineID = task.routineID {
                // Only feeds the read-only summary; a failure leaves the row empty, never blocks editing.
                editingRoutine = try? await getRoutine.execute(id: routineID, accessToken: accessToken)
            }
            initialSnapshot = Snapshot(title: title, weight: weight, scheduledDate: scheduledDate, note: note, assigneeIDs: assigneeIDs, frequency: nil)
        } catch {
            loadFailed = true
        }
    }

    /// The signed-in member first, then the others in the directory order (Figma MOD-001).
    var orderedMembers: [FamilyMember] {
        let current = availableMembers.filter { $0.id == currentMemberID }
        return current + availableMembers.filter { $0.id != currentMemberID }
    }

    func displayName(for member: FamilyMember) -> String {
        member.id == currentMemberID ? String(localized: "tasks.detail.you") : member.name
    }

    func setAssignees(_ ids: Set<UUID>) {
        assigneeIDs = ids
    }

    /// Resolves the family's current civil date before MOD-002 can offer a default start date.
    func prepareRecurrencePicker() async {
        guard mode == .create, !isRecurrencePickerPresented else { return }
        banner = nil
        do {
            let timeZoneID: String
            if let familyTimeZoneID {
                timeZoneID = familyTimeZoneID
            } else {
                timeZoneID = try await routineRepository.familyTimeZoneID(accessToken: accessToken)
                familyTimeZoneID = timeZoneID
            }
            if let initialSnapshot, scheduledDate == initialSnapshot.scheduledDate {
                let familyToday = Self.wireString(from: today(), timeZoneID: timeZoneID)
                if let adjusted = Self.date(fromWire: familyToday) {
                    scheduledDate = adjusted
                    self.initialSnapshot = Snapshot(
                        title: initialSnapshot.title,
                        weight: initialSnapshot.weight,
                        scheduledDate: adjusted,
                        note: initialSnapshot.note,
                        assigneeIDs: initialSnapshot.assigneeIDs,
                        frequency: initialSnapshot.frequency
                    )
                }
            }
            isRecurrencePickerPresented = true
        } catch {
            banner = .routineUnavailable
        }
    }

    func setRecurrence(startDate: Date, frequency: RoutineFrequency?) {
        scheduledDate = startDate
        self.frequency = frequency
        startDateError = false
        frequencyError = false
        isRecurrencePickerPresented = false
    }

    /// MOD-001's member list is small (a family), so a single page is always requested.
    func loadAssigneeCandidatesIfNeeded() async {
        guard !hasLoadedMembers, !isLoadingMembers else {
            return
        }
        isLoadingMembers = true
        membersLoadFailed = false
        defer { isLoadingMembers = false }

        do {
            let page = try await familyRepository.listMembers(accessToken: accessToken, cursor: nil)
            availableMembers = page.items
            hasLoadedMembers = true
        } catch {
            membersLoadFailed = true
        }
    }

    /// CA-14: a pending signal must be resolved on every save, even when only the note changed.
    /// Public and `async` so both the View (wrapped in its own `Task`) and tests can await it directly.
    func saveIfValid() async {
        guard validate() else {
            return
        }
        // MOD-014 belongs to individual edits only; the routine scope never changes states (SPEC-008 E-08).
        if routineScope != .thisAndFuture, currentStatus == .awaitingConfirmation, signalResolutionChoice == nil {
            isSignalResolutionPresented = true
            return
        }
        await save()
    }

    func chooseSignalResolution(_ choice: SignalResolution) {
        signalResolutionChoice = choice
    }

    func confirmSignalResolutionAndSave() async {
        guard signalResolutionChoice != nil else {
            return
        }
        isSignalResolutionPresented = false
        await save()
    }

    func cancelSignalResolution() {
        isSignalResolutionPresented = false
    }

    // MARK: Private

    private func validate() -> Bool {
        switch TaskValidation.validatedTitle(title) {
        case .success:
            titleError = nil
        case let .failure(error):
            titleError = error == .required ? .required : .invalid
        }
        switch TaskValidation.validatedNote(note) {
        case .success:
            noteError = nil
        case .failure:
            noteError = .invalid
        }
        return titleError == nil && noteError == nil && weight != nil
    }

    /// Draft fields are never cleared here on failure: CA-11 is satisfied by construction.
    private func save() async {
        guard case let .success(validatedTitle) = TaskValidation.validatedTitle(title),
              case let .success(validatedNote) = TaskValidation.validatedNote(note),
              let weight else {
            return
        }

        isSaving = true
        banner = nil
        defer { isSaving = false }

        let scheduledDateString = Self.wireString(from: scheduledDate)
        do {
            switch mode {
            case .create:
                if let frequency {
                    savedRoutine = try await createRoutine.execute(
                        CreateRoutineCommand(
                            title: validatedTitle,
                            weight: weight,
                            assigneeIDs: Array(assigneeIDs),
                            note: validatedNote,
                            startDate: scheduledDateString,
                            frequency: frequency
                        ),
                        accessToken: accessToken
                    )
                } else {
                    savedTask = try await createTask.execute(
                        CreateTaskCommand(
                            title: validatedTitle,
                            weight: weight,
                            scheduledDate: scheduledDateString,
                            assigneeIDs: Array(assigneeIDs),
                            note: validatedNote
                        ),
                        accessToken: accessToken
                    )
                }
            case let .edit(_, .thisAndFuture?):
                guard let loadedTask, let routineID = loadedTask.routineID else { return }
                _ = try await updateFutureRoutine.execute(
                    routineID: routineID,
                    command: UpdateFutureRoutineCommand(
                        fromTaskID: loadedTask.id,
                        title: validatedTitle,
                        weight: weight,
                        assigneeIDs: Array(assigneeIDs),
                        note: validatedNote
                    ),
                    accessToken: accessToken
                )
                // Date and state are untouched by this scope, so the occurrence is rebuilt locally.
                savedTask = FamilyTask(
                    id: loadedTask.id,
                    title: validatedTitle,
                    weight: weight,
                    scheduledDate: loadedTask.scheduledDate,
                    assigneeIDs: Array(assigneeIDs),
                    note: validatedNote,
                    status: loadedTask.status,
                    routineID: routineID,
                    createdAt: loadedTask.createdAt
                )
            case let .edit(taskID, _):
                savedTask = try await updateTask.execute(
                    UpdateTaskCommand(
                        taskID: taskID,
                        title: validatedTitle,
                        weight: weight,
                        scheduledDate: scheduledDateString,
                        assigneeIDs: Array(assigneeIDs),
                        note: validatedNote,
                        signalResolution: signalResolutionChoice
                    ),
                    accessToken: accessToken
                )
            }
        } catch {
            if routineScope == .thisAndFuture {
                handleFutureRoutineFailure(error)
            } else if frequency != nil, mode == .create {
                handleRoutineFailure(error)
            } else {
                handleSaveFailure(error)
            }
        }
    }

    private func handleRoutineFailure(_ error: Error) {
        switch error as? RoutineError {
        case .uncertainOutcome, .network, .unavailable:
            banner = .routineUncertainOutcome
        case .actionNotAllowed:
            banner = .actionNotAllowed
        case let .validationFailed(fieldErrors):
            if fieldErrors["title"] != nil { titleError = .invalid }
            if fieldErrors["note"] != nil { noteError = .invalid }
            startDateError = fieldErrors["startDate"] != nil
            frequencyError = fieldErrors["frequencyDays"] != nil
            banner = .rejected
        case .notFound, .rejected, .missionProtected, .missionWouldHaveNoTasks, nil:
            banner = .rejected
        }
    }

    private func handleFutureRoutineFailure(_ error: Error) {
        switch error as? RoutineError {
        case .uncertainOutcome, .network, .unavailable:
            banner = .routineUncertainOutcome
        case .actionNotAllowed:
            banner = .actionNotAllowed
        case .missionProtected:
            banner = .missionProtected
        case let .validationFailed(fieldErrors):
            if fieldErrors["title"] != nil { titleError = .invalid }
            if fieldErrors["note"] != nil { noteError = .invalid }
            banner = fieldErrors["fromTaskId"] != nil ? .routineSourceInvalid : .rejected
        case .notFound, .rejected, .missionWouldHaveNoTasks, nil:
            banner = .rejected
        }
    }

    private func handleSaveFailure(_ error: Error) {
        switch error as? TaskError {
        case .uncertainOutcome:
            banner = .uncertainOutcome
        case .network:
            banner = .networkFailure
        case .actionNotAllowed:
            banner = .actionNotAllowed
        case .missionCompletedProtected:
            banner = .missionProtected
        case let .validationFailed(fieldErrors):
            if fieldErrors["title"] != nil {
                titleError = .invalid
            }
            if fieldErrors["note"] != nil {
                noteError = .invalid
            }
            banner = .rejected
        case .signalResolutionRequired:
            isSignalResolutionPresented = true
        case .notFound, .alreadyCompleted, .missionWouldHaveNoTasks, .rejected, .unavailable,
             .taskNotCompleted, .missionReopenRequiresConfirmation, nil:
            // Never thrown by create/update — reopening-only cases (SPEC-011); same fallback as any other rejection.
            banner = .rejected
        }
    }

    var recurrenceSummary: String {
        guard let frequency else { return String(localized: "routines.recurrence.none") }
        return Self.summary(for: frequency)
    }

    private static func summary(for frequency: RoutineFrequency) -> String {
        if frequency == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), frequency.rawValue)
    }

    private static func wireString(from date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func date(fromWire wire: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: wire)
    }
}
