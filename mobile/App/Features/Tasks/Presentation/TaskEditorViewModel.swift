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
}

enum TaskEditorMode: Equatable {
    case create
    case edit(UUID)
}

/// Backs TEL-013 (single-task fields only — recurrence belongs to SPEC-008). Pushed, never a sheet.
@MainActor
@Observable
final class TaskEditorViewModel {
    private let mode: TaskEditorMode
    private let getTaskDetail: GetTaskDetailUseCase
    private let createTask: CreateTaskUseCase
    private let updateTask: UpdateTaskUseCase
    private let familyRepository: any FamilyRepository
    private let accessToken: String
    private let today: () -> Date

    var title = ""
    var weight: EffortWeight?
    var scheduledDate: Date
    var note = ""
    private(set) var assigneeIDs: Set<UUID> = []

    private(set) var titleError: TaskFieldError?
    private(set) var noteError: TaskFieldError?

    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// Set once the existing task loads in edit mode; `nil` while creating or still loading.
    private(set) var currentStatus: TaskStatus?

    private(set) var isSaving = false
    private(set) var banner: TaskEditorBanner?
    private(set) var savedTask: FamilyTask?

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
    }
    private var initialSnapshot: Snapshot?

    init(
        mode: TaskEditorMode,
        repository: any TaskRepository,
        familyRepository: any FamilyRepository,
        accessToken: String,
        today: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.createTask = CreateTaskUseCase(repository: repository)
        self.updateTask = UpdateTaskUseCase(repository: repository)
        self.familyRepository = familyRepository
        self.accessToken = accessToken
        self.today = today
        self.scheduledDate = today()
        if mode == .create {
            initialSnapshot = Snapshot(title: "", weight: nil, scheduledDate: self.scheduledDate, note: "", assigneeIDs: [])
        }
    }

    /// Drives the "Descartar alterações?" confirmation when leaving TEL-013 (UX-007 §4).
    var hasUnsavedChanges: Bool {
        guard let initialSnapshot else {
            return false
        }
        let current = Snapshot(title: title, weight: weight, scheduledDate: scheduledDate, note: note, assigneeIDs: assigneeIDs)
        return current != initialSnapshot
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// The form only enables Salvar once title and weight are both valid (UX-007 §5.1).
    var isFormValid: Bool {
        guard case .success = TaskValidation.validatedTitle(title) else {
            return false
        }
        return weight != nil
    }

    func load() async {
        guard case let .edit(taskID) = mode else {
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
            initialSnapshot = Snapshot(title: title, weight: weight, scheduledDate: scheduledDate, note: note, assigneeIDs: assigneeIDs)
        } catch {
            loadFailed = true
        }
    }

    func setAssignees(_ ids: Set<UUID>) {
        assigneeIDs = ids
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
        if currentStatus == .awaitingConfirmation, signalResolutionChoice == nil {
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
            case let .edit(taskID):
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
            handleSaveFailure(error)
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
