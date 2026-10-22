import Foundation
import Observation

/// Non-blocking feedback banner for a failed delete that isn't one of the two named MOD-005 blocks.
enum TaskDetailBanner: Equatable {
    case deleteFailed
    case loadFailed
}

/// MOD-005's two blocking variants that stop the delete flow outright, as opposed to the
/// ordinary Cancelar/Excluir confirmation (UX-007 §5.4).
enum TaskDeleteBlock: Equatable {
    case alreadyCompleted
    case missionProtected
}

/// Backs TEL-012 (Editar/Excluir only — Concluir/Reabrir stay hidden per UX-03, out of this card's scope).
@MainActor
@Observable
final class TaskDetailViewModel {
    private let taskID: UUID
    private let getTaskDetail: GetTaskDetailUseCase
    private let deleteTask: DeleteTaskUseCase
    private let accessToken: String

    private(set) var task: FamilyTask?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var isDeleting = false
    private(set) var deleteBlock: TaskDeleteBlock?
    private(set) var banner: TaskDetailBanner?
    private(set) var isDeleted = false

    var isConfirmingDelete = false

    init(taskID: UUID, repository: any TaskRepository, accessToken: String) {
        self.taskID = taskID
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.deleteTask = DeleteTaskUseCase(repository: repository)
        self.accessToken = accessToken
    }

    /// CA-06: a completed task's delete row is disabled with an inline explanation, never a confirmation.
    var canDeleteDirectly: Bool {
        task?.status != .completed
    }

    var hasPendingSignal: Bool {
        task?.status == .awaitingConfirmation
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            task = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
        } catch {
            loadFailed = true
        }
    }

    func requestDelete() {
        guard canDeleteDirectly else {
            return
        }
        isConfirmingDelete = true
    }

    func confirmDelete() async {
        isConfirmingDelete = false
        isDeleting = true
        banner = nil
        defer { isDeleting = false }

        do {
            _ = try await deleteTask.execute(taskID: taskID, accessToken: accessToken)
            isDeleted = true
        } catch TaskError.alreadyCompleted {
            deleteBlock = .alreadyCompleted
        } catch TaskError.missionCompletedProtected {
            deleteBlock = .missionProtected
        } catch {
            banner = .deleteFailed
        }
    }

    func dismissDeleteBlock() {
        deleteBlock = nil
    }
}
