import Foundation
import Observation

/// Non-blocking feedback banner for a failed delete that isn't one of the two named MOD-005 blocks.
enum TaskDetailBanner: Equatable {
    case deleteFailed
    case loadFailed
    /// A routine-scope deletion whose result could not be confirmed; the detail was reloaded.
    case deleteUncertain
}

/// MOD-005's two blocking variants that stop the delete flow outright, as opposed to the
/// ordinary Cancelar/Excluir confirmation (UX-007 §5.4).
enum TaskDeleteBlock: Equatable {
    case alreadyCompleted
    case missionProtected
    /// `MISSION_WOULD_HAVE_NO_TASKS` on "Esta tarefa e as futuras" (SPEC-008 E-11).
    case missionWouldHaveNoTasks
}

/// MOD-006's content, populated from `TaskError.missionReopenRequiresConfirmation` (SPEC-011 §5.2).
struct MissionReopenPrompt: Equatable {
    let missionsAffected: [AffectedMission]
    let hasAcceptedReward: Bool
}

enum TaskCompletionFailure: Equatable {
    case needsRefresh
    case notCompleted
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
    private let familyRepository: (any FamilyRepository)?
    private let deleteTask: DeleteTaskUseCase
    private let deleteFutureRoutineTasks: DeleteFutureRoutineTasksUseCase
    private let completeTask: CompleteTaskUseCase
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
    private(set) var isCompleting = false
    private(set) var completionFailure: TaskCompletionFailure?
    private(set) var completionRevision = 0
    private(set) var memberRolesLoadFailed = false
    private(set) var memberDirectoryLoadFailed = false
    private(set) var memberNames: [UUID: String] = [:]
    private var memberRoles: [UUID: MemberRole]?

    var isConfirmingDelete = false
    /// MOD-003 is showing for this purpose (routine occurrences only, UX-008 §5.4).
    var scopePrompt: RoutineScopePurpose?
    /// Scope chosen in MOD-003 for the deletion MOD-005 is confirming.
    private(set) var pendingDeleteScope: RoutineScope?

    init(
        taskID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: (any FamilyRepository)? = nil,
        accessToken: String
    ) {
        self.taskID = taskID
        self.role = role
        self.currentMemberID = currentMemberID
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.getRoutine = GetRoutineUseCase(repository: routineRepository)
        self.familyRepository = familyRepository
        self.deleteTask = DeleteTaskUseCase(repository: repository)
        self.deleteFutureRoutineTasks = DeleteFutureRoutineTasksUseCase(repository: routineRepository)
        self.completeTask = CompleteTaskUseCase(repository: repository)
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

    /// SPEC-010 CA-04: never offer the Member action until every assignee's role is known.
    /// The backend rechecks this inside its transaction; this is only a presentation guard.
    var showsCompleteAction: Bool {
        guard let task, task.status != .completed else {
            return false
        }
        switch role {
        case .administrator:
            return true
        case .member:
            if task.assigneeIDs.isEmpty { return true }
            guard let memberRoles else { return false }
            return task.assigneeIDs.allSatisfy { memberRoles[$0] != nil && memberRoles[$0] != .kid }
        case .kid:
            return false
        }
    }

    var canComplete: Bool {
        showsCompleteAction && !isCompleting && completionFailure != .needsRefresh
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
            completionFailure = nil
            await loadMemberDirectoryIfNeeded()
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

    func retryMemberRoles() async {
        await loadMemberDirectoryIfNeeded()
    }

    private func loadMemberDirectoryIfNeeded() async {
        memberRoles = nil
        memberRolesLoadFailed = false
        memberDirectoryLoadFailed = false
        memberNames = [:]
        guard role != .kid, let task, !task.assigneeIDs.isEmpty else {
            return
        }
        guard let familyRepository else {
            memberDirectoryLoadFailed = true
            memberRolesLoadFailed = role == .member && task.status != .completed
            return
        }
        do {
            var roles: [UUID: MemberRole] = [:]
            var names: [UUID: String] = [:]
            var cursor: String?
            var seenCursors = Set<String>()
            repeat {
                let page = try await familyRepository.listMembers(accessToken: accessToken, cursor: cursor)
                for member in page.items {
                    roles[member.id] = member.role
                    names[member.id] = member.name
                }
                cursor = page.nextCursor
                if let cursor, !seenCursors.insert(cursor).inserted {
                    throw FamilyError.unavailable
                }
            } while cursor != nil
            memberNames = names
            memberDirectoryLoadFailed = task.assigneeIDs.contains { names[$0] == nil }
            if role == .member && task.status != .completed {
                memberRoles = roles
                memberRolesLoadFailed = task.assigneeIDs.contains { roles[$0] == nil }
            }
        } catch {
            memberDirectoryLoadFailed = true
            memberRolesLoadFailed = role == .member && task.status != .completed
        }
    }

    /// SPEC-010 Fase 2 CA-01/02/05/06. The POST is never replayed automatically.
    func requestComplete() async {
        guard canComplete else { return }
        isCompleting = true
        completionFailure = nil
        showReopenSuccessBanner = false
        defer { isCompleting = false }

        do {
            task = try await completeTask.execute(taskID: taskID, accessToken: accessToken)
            if task?.status == .completed {
                completionRevision += 1
            } else {
                completionFailure = .needsRefresh
            }
        } catch TaskError.alreadyCompleted {
            await reconcileCompletion()
        } catch TaskError.uncertainOutcome {
            await reconcileCompletion()
        } catch {
            completionFailure = .needsRefresh
        }
    }

    /// Checks the canonical state before another explicit command after an uncertain result.
    func refreshCompletionStatus() async {
        guard !isCompleting, completionFailure != nil else { return }
        isCompleting = true
        defer { isCompleting = false }
        await reconcileCompletion()
    }

    private func reconcileCompletion() async {
        do {
            let latest = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
            task = latest
            if latest.status == .completed {
                completionFailure = nil
                completionRevision += 1
            } else {
                await loadMemberDirectoryIfNeeded()
                completionFailure = .notCompleted
            }
        } catch {
            completionFailure = .needsRefresh
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

    var isRoutineOccurrence: Bool {
        task?.routineID != nil
    }

    /// Short MOD-003 summary: "{título} · {data curta}" (UX-008 §5.3).
    var scopeSummary: String {
        guard let task else { return "" }
        guard let date = Self.date(fromWire: task.scheduledDate) else { return task.title }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(task.title) · \(day)"
    }

    /// Editing a routine occurrence always asks for the scope first (UX-008 UX-04). Returns
    /// `true` when the caller can open TEL-013 right away (a single task).
    func requestEdit() -> Bool {
        guard canManageTask, task != nil else { return false }
        if isRoutineOccurrence {
            scopePrompt = .edit
            return false
        }
        return true
    }

    func requestDelete() {
        guard canManageTask, canDeleteDirectly, !isDeleting, task != nil else {
            return
        }
        if isRoutineOccurrence {
            scopePrompt = .delete
        } else {
            pendingDeleteScope = nil
            isConfirmingDelete = true
        }
    }

    /// MOD-003 confirmed for a deletion: MOD-005 still confirms it (UX-008 §4).
    func chooseDeleteScope(_ scope: RoutineScope) {
        scopePrompt = nil
        pendingDeleteScope = scope
        isConfirmingDelete = true
    }

    func confirmDelete() async {
        guard canManageTask, canDeleteDirectly, !isDeleting, let task else { return }
        isConfirmingDelete = false
        isDeleting = true
        banner = nil
        defer { isDeleting = false }

        if let routineID = task.routineID, pendingDeleteScope == .thisAndFuture {
            await deleteFromHereOn(routineID: routineID, task: task)
            return
        }
        do {
            _ = try await deleteTask.execute(taskID: taskID, accessToken: accessToken)
            isDeleted = true
        } catch TaskError.alreadyCompleted {
            deleteBlock = .alreadyCompleted
        } catch TaskError.missionCompletedProtected {
            deleteBlock = .missionProtected
        } catch TaskError.missionWouldHaveNoTasks {
            deleteBlock = .missionWouldHaveNoTasks
        } catch {
            banner = .deleteFailed
        }
    }

    /// CA-08: the open occurrence and the following ones; the routine stops generating.
    private func deleteFromHereOn(routineID: UUID, task: FamilyTask) async {
        do {
            _ = try await deleteFutureRoutineTasks.execute(
                routineID: routineID,
                fromTaskID: task.id,
                accessToken: accessToken
            )
            isDeleted = true
        } catch RoutineError.missionWouldHaveNoTasks {
            deleteBlock = .missionWouldHaveNoTasks
        } catch RoutineError.uncertainOutcome {
            // Never retried automatically: reload so the screen shows the canonical state (CA-10).
            banner = .deleteUncertain
            await reloadAfterUncertainDelete()
        } catch {
            banner = .deleteFailed
        }
    }

    private func reloadAfterUncertainDelete() async {
        do {
            task = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
        } catch TaskError.notFound {
            isDeleted = true
        } catch {
            // Keep the last known state; the banner already says the result is unconfirmed.
        }
    }

    private static func date(fromWire wire: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: wire)
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
