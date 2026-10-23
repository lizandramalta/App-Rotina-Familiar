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

/// MOD-006's content, populated from `TaskError.missionReopenRequiresConfirmation` (SPEC-011 §5.2).
struct MissionReopenPrompt: Equatable {
    let missionsAffected: [AffectedMission]
    let hasAcceptedReward: Bool
}

/// Backs TEL-012: Editar/Excluir (Admin/Membro only, SPEC-007/UX-011 §4) and Reabrir
/// (Admin/Membro always, Kids only on their own task — SPEC-011 §4).
@MainActor
@Observable
final class TaskDetailViewModel {
    private let taskID: UUID
    let role: MemberRole
    private let currentMemberID: UUID
    private let getTaskDetail: GetTaskDetailUseCase
    private let getRoutine: GetRoutineUseCase
    private let deleteTask: DeleteTaskUseCase
    private let reopenTask: ReopenTaskUseCase
    private let accessToken: String

    private(set) var task: FamilyTask?
    private(set) var routine: Routine?
    private(set) var routineLoadFailed = false
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var isDeleting = false
    private(set) var deleteBlock: TaskDeleteBlock?
    private(set) var banner: TaskDetailBanner?
    private(set) var isDeleted = false
    private(set) var isReopening = false
    private(set) var missionReopenPrompt: MissionReopenPrompt?
    private(set) var reopenFailed = false
    private(set) var showReopenSuccessBanner = false

    var isConfirmingDelete = false

    init(
        taskID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any TaskRepository,
        routineRepository: any RoutineRepository,
        accessToken: String
    ) {
        self.taskID = taskID
        self.role = role
        self.currentMemberID = currentMemberID
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.getRoutine = GetRoutineUseCase(repository: routineRepository)
        self.deleteTask = DeleteTaskUseCase(repository: repository)
        self.reopenTask = ReopenTaskUseCase(repository: repository)
        self.accessToken = accessToken
    }

    /// Kids never edits or deletes a task — including their own (SPEC-007, UX-011 §4 Figma variant).
    var canManageTask: Bool {
        role != .kid
    }

    /// CA-06: a completed task's delete row is disabled with an inline explanation, never a confirmation.
    var canDeleteDirectly: Bool {
        task?.status != .completed
    }

    var hasPendingSignal: Bool {
        task?.status == .awaitingConfirmation
    }

    /// Admin/Membro: any completed task. Kids: only their own (SPEC-011 §4, RBAC).
    var canReopen: Bool {
        guard let task, task.status == .completed else { return false }
        if role == .kid {
            return task.assigneeIDs.contains(currentMemberID)
        }
        return true
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            task = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
            if role != .kid, let routineID = task?.routineID {
                await loadRoutine(id: routineID)
            } else {
                routine = nil
                routineLoadFailed = false
            }
        } catch {
            loadFailed = true
        }
    }

    func refreshRoutine() async {
        guard role != .kid, let routineID = task?.routineID else { return }
        await loadRoutine(id: routineID)
    }

    private func loadRoutine(id: UUID) async {
        do {
            routine = try await getRoutine.execute(id: id, accessToken: accessToken)
            routineLoadFailed = false
        } catch {
            routineLoadFailed = true
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

    /// Always calls without `confirm` first (SPEC-011 E-01) — never pre-calculates mission impact.
    func requestReopen() async {
        guard canReopen, !isReopening else {
            return
        }
        await performReopen(confirm: false)
    }

    /// Resends with `confirm: true` after the server named the affected missions via MOD-006.
    func confirmMissionReopen() async {
        guard missionReopenPrompt != nil, !isReopening else {
            return
        }
        await performReopen(confirm: true)
    }

    func cancelMissionReopen() {
        missionReopenPrompt = nil
    }

    private func performReopen(confirm: Bool) async {
        isReopening = true
        reopenFailed = false
        defer { isReopening = false }

        do {
            task = try await reopenTask.execute(taskID: taskID, confirm: confirm, accessToken: accessToken)
            missionReopenPrompt = nil
            showReopenSuccessBanner = true
        } catch TaskError.missionReopenRequiresConfirmation(let missionsAffected, let hasAcceptedReward) {
            missionReopenPrompt = MissionReopenPrompt(missionsAffected: missionsAffected, hasAcceptedReward: hasAcceptedReward)
        } catch TaskError.taskNotCompleted {
            // UX-011 §2: never shown as a technical error — just reflect the current state.
            missionReopenPrompt = nil
            await load()
        } catch TaskError.notFound {
            missionReopenPrompt = nil
            await load()
        } catch {
            missionReopenPrompt = nil
            reopenFailed = true
        }
    }
}
