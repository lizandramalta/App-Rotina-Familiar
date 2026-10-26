import Foundation
import Observation

enum MissionFieldError: Equatable {
    case required
    case invalid
}

/// Non-blocking feedback after a failed save (mirrors `TaskEditorBanner`, UX-014 §6 "Error não bloqueante").
enum MissionEditorBanner: Equatable {
    case networkFailure
    case uncertainOutcome
    case actionNotAllowed
    case completedProtected
    case rejected
}

enum MissionEditorMode: Equatable {
    case create
    case edit(UUID)
}

/// Backs TEL-022 (SPEC-014 Fase 2, CA-09/CA-12). Pushed, never a sheet — same 2026-10-19 design
/// decision already applied to TEL-013, so MOD-007's own sheet never stacks over another sheet.
@MainActor
@Observable
final class MissionEditorViewModel {
    private let mode: MissionEditorMode
    private let getMissionDetail: GetMissionDetailUseCase
    private let createMission: CreateMissionUseCase
    private let updateMission: UpdateMissionUseCase
    private let hydrateLinkedTasks: HydrateLinkedTasksUseCase
    private let accessToken: String

    var title = ""
    var note = ""
    private(set) var linkedTasks: [MissionTaskOption] = []

    private(set) var titleError: MissionFieldError?
    private(set) var noteError: MissionFieldError?

    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var currentStatus: MissionStatus?

    private(set) var isSaving = false
    private(set) var banner: MissionEditorBanner?
    private(set) var savedMission: Mission?

    var isTaskPickerPresented = false

    private struct Snapshot: Equatable {
        let title: String
        let note: String
        let linkedTaskIDs: Set<UUID>
    }
    private var initialSnapshot: Snapshot?

    init(
        mode: MissionEditorMode,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        accessToken: String
    ) {
        self.mode = mode
        self.getMissionDetail = GetMissionDetailUseCase(repository: repository)
        self.createMission = CreateMissionUseCase(repository: repository)
        self.updateMission = UpdateMissionUseCase(repository: repository)
        self.hydrateLinkedTasks = HydrateLinkedTasksUseCase(taskRepository: taskRepository)
        self.accessToken = accessToken
        if mode == .create {
            initialSnapshot = Snapshot(title: "", note: "", linkedTaskIDs: [])
        }
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// Drives the "Descartar alterações?" confirmation when leaving TEL-022 (UX-014 §4).
    var hasUnsavedChanges: Bool {
        guard let initialSnapshot else {
            return false
        }
        let current = Snapshot(title: title, note: note, linkedTaskIDs: Set(linkedTasks.map(\.id)))
        return current != initialSnapshot
    }

    /// CA-12: Salvar só habilita com título válido e ao menos uma tarefa vinculada. Este é o único
    /// bloqueio "sem tarefas" do fluxo — MOD-007 sempre permite Confirmar (UX-014 §5.2, decisão
    /// registrada: seguir o texto da spec em vez do protótipo, que mostrava o ✓ do próprio MOD-007
    /// desativado nesse estado).
    var isFormValid: Bool {
        guard case .success = MissionValidation.validatedTitle(title) else {
            return false
        }
        return !linkedTasks.isEmpty
    }

    /// Texto inline explicando o bloqueio "sem tarefas" (missions.form.error_tasks_required).
    var showsTasksRequiredError: Bool {
        linkedTasks.isEmpty
    }

    func load() async {
        guard case let .edit(missionID) = mode else {
            return
        }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let mission = try await getMissionDetail.execute(missionID: missionID, accessToken: accessToken)
            // Only committed once both calls succeed, so a hydration failure never leaves the form
            // partially populated behind `loadFailed`'s full-screen error state.
            let tasks = try await hydrateLinkedTasks.execute(taskIDs: mission.taskIDs, accessToken: accessToken)
            title = mission.title
            note = mission.note ?? ""
            currentStatus = mission.status
            linkedTasks = tasks
            initialSnapshot = Snapshot(title: title, note: note, linkedTaskIDs: Set(linkedTasks.map(\.id)))
        } catch {
            loadFailed = true
        }
    }

    func openTaskPicker() {
        isTaskPickerPresented = true
    }

    /// Written back only when MOD-007's Confirmar is tapped — Cancelar/fechar leaves this draft untouched.
    func applyPickerSelection(_ tasks: [MissionTaskOption]) {
        linkedTasks = tasks
    }

    /// Public and `async` so both the View (wrapped in its own `Task`) and tests can await it directly.
    func saveIfValid() async {
        guard validate() else {
            return
        }
        await save()
    }

    // MARK: Private

    private func validate() -> Bool {
        switch MissionValidation.validatedTitle(title) {
        case .success:
            titleError = nil
        case let .failure(error):
            titleError = error == .required ? .required : .invalid
        }
        switch MissionValidation.validatedNote(note) {
        case .success:
            noteError = nil
        case .failure:
            noteError = .invalid
        }
        return titleError == nil && noteError == nil && !linkedTasks.isEmpty
    }

    /// Draft fields are never cleared here on failure — same CA-11-style guarantee `TaskEditorViewModel` gives Tasks.
    private func save() async {
        guard case let .success(validatedTitle) = MissionValidation.validatedTitle(title),
              case let .success(validatedNote) = MissionValidation.validatedNote(note),
              !linkedTasks.isEmpty else {
            return
        }

        isSaving = true
        banner = nil
        defer { isSaving = false }

        let taskIDs = linkedTasks.map(\.id)
        do {
            switch mode {
            case .create:
                savedMission = try await createMission.execute(
                    CreateMissionCommand(title: validatedTitle, note: validatedNote, taskIDs: taskIDs),
                    accessToken: accessToken
                )
            case let .edit(missionID):
                savedMission = try await updateMission.execute(
                    UpdateMissionCommand(missionID: missionID, title: validatedTitle, note: validatedNote, taskIDs: taskIDs),
                    accessToken: accessToken
                )
            }
        } catch {
            handleSaveFailure(error)
        }
    }

    private func handleSaveFailure(_ error: Error) {
        switch error as? MissionError {
        case .uncertainOutcome:
            banner = .uncertainOutcome
        case .network:
            banner = .networkFailure
        case .actionNotAllowed:
            banner = .actionNotAllowed
        case .completedProtected:
            banner = .completedProtected
        case let .validationFailed(fieldErrors):
            if fieldErrors["title"] != nil {
                titleError = .invalid
            }
            if fieldErrors["note"] != nil {
                noteError = .invalid
            }
            banner = .rejected
        case .notFound, .wouldHaveNoTasks, .rejected, .unavailable, nil:
            banner = .rejected
        }
    }
}
