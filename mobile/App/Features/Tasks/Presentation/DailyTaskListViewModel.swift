import Observation
import SwiftUI

/// Who the checklist belongs to. The backend already projects `displayStatus` per actor role
/// (SPEC-009 §5), so this only toggles presentation differences that aren't in the DTO.
enum TaskAudience: Equatable, Sendable {
    case adult
    case kid
}

enum TaskListActionAlert: Equatable {
    case failed
    case uncertain
}

/// Backs TEL-010/TEL-040 (SPEC-009 Fase 1 — own daily checklist, both profiles).
@MainActor
@Observable
final class DailyTaskListViewModel {
    let audience: TaskAudience
    private let getDailyTasks: GetDailyTasksUseCase
    private let getDailyProgress: GetDailyProgressUseCase
    private let getTaskDetail: GetTaskDetailUseCase
    private let completeTask: CompleteTaskUseCase
    private let reopenTask: ReopenTaskUseCase
    private let familyRepository: (any FamilyRepository)?
    private let accessToken: String
    let role: MemberRole
    private let currentMemberID: UUID
    private let today: () -> Date
    private let calendar: Calendar

    private(set) var selectedDate: Date
    private(set) var items: [OwnTaskListItem] = []
    private(set) var progress: DailyProgress?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var actionInFlight: Set<UUID> = []
    private(set) var actionFailure: TaskCompletionFailure?
    private(set) var actionFailureTaskID: UUID?
    private(set) var actionAlert: TaskListActionAlert?
    private(set) var missionReopenPrompt: MissionReopenPrompt?
    private(set) var missionReopenTaskID: UUID?
    private(set) var lastChangedTaskID: UUID?
    private(set) var actionRevision = 0
    private var memberRoles: [UUID: MemberRole]?
    private var serverItems: [OwnTaskListItem] = []
    private var serverProgress: DailyProgress?
    private var canonicalTasks: [UUID: FamilyTask] = [:]
    private var desiredCompleted: [UUID: Bool] = [:]
    private var intentRevisions: [UUID: Int] = [:]
    private var confirmedReopenIDs: Set<UUID> = []
    private var unresolvedTasks: Set<UUID> = []
    /// RN49's lower bound (SPEC-009 E-05), learned from the first successful load. `nil` until
    /// then: with no loaded value yet, no past date is speculatively blocked.
    private(set) var familyCreatedAt: Date?

    init(
        audience: TaskAudience,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any TaskRepository,
        familyRepository: (any FamilyRepository)? = nil,
        accessToken: String,
        today: @escaping () -> Date = Date.init
    ) {
        self.audience = audience
        self.getDailyTasks = GetDailyTasksUseCase(repository: repository)
        self.getDailyProgress = GetDailyProgressUseCase(repository: repository)
        self.getTaskDetail = GetTaskDetailUseCase(repository: repository)
        self.completeTask = CompleteTaskUseCase(repository: repository)
        self.reopenTask = ReopenTaskUseCase(repository: repository)
        self.familyRepository = familyRepository
        self.accessToken = accessToken
        self.role = role
        self.currentMemberID = currentMemberID
        self.today = today
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar
        self.selectedDate = calendar.startOfDay(for: today())
    }

    var isEmpty: Bool {
        !isLoading && !loadFailed && items.isEmpty
    }

    /// RN49: between the family's creation date and the last day of the current month, both
    /// inclusive (SPEC-009 E-05). The lower bound is only known after a successful load — until
    /// then, no past date is speculatively blocked (there is nothing to compare against yet).
    func isDateAvailable(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day <= Self.endOfCurrentMonth(from: today(), calendar: calendar) else {
            return false
        }
        guard let familyCreatedAt else {
            return true
        }
        return day >= familyCreatedAt
    }

    /// Call on first appearance and from the error state's retry action. Never clears already
    /// shown data on failure (CA-09): a background refresh failing keeps the last known list and
    /// progress visible with a non-blocking banner, rather than flashing an empty/zeroed state.
    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        let referenceDate = Self.wireString(from: selectedDate)
        do {
            async let tasksResult = getDailyTasks.execute(referenceDate: referenceDate, cursor: nil, accessToken: accessToken)
            async let progressResult = getDailyProgress.execute(referenceDate: referenceDate, accessToken: accessToken)
            let (page, progress) = try await (tasksResult, progressResult)
            guard referenceDate == Self.wireString(from: selectedDate) else { return }
            var completedAdjustment = 0
            serverItems = page.items.map { item in
                guard actionInFlight.contains(item.id), let known = canonicalTasks[item.id],
                      known.status != item.task.status else { return item }
                if (known.status == .completed) != (item.task.status == .completed) {
                    completedAdjustment += known.status == .completed ? 1 : -1
                }
                return OwnTaskListItem(
                    task: known,
                    displayStatus: known.status == .awaitingConfirmation && audience == .adult ? .pending : known.status
                )
            }
            if completedAdjustment == 0 {
                serverProgress = progress
            } else {
                let completed = min(progress.total, max(0, progress.completed + completedAdjustment))
                serverProgress = DailyProgress(
                    total: progress.total, completed: completed,
                    percentage: progress.total == 0 ? nil : Double(completed) / Double(progress.total) * 100,
                    familyCreatedAt: progress.familyCreatedAt
                )
            }
            for item in page.items where !actionInFlight.contains(item.id) {
                canonicalTasks[item.id] = item.task
            }
            publishOptimisticState()
            familyCreatedAt = Self.date(fromWire: page.familyCreatedAt) ?? familyCreatedAt
            await loadMemberRolesIfNeeded()
        } catch {
            loadFailed = true
        }
    }

    /// Uses the effective status, never the role-specific display label (SPEC-009 CA-11).
    func showsToggle(_ item: OwnTaskListItem) -> Bool {
        if item.task.status == .completed {
            return role != .kid || item.task.assigneeIDs.contains(currentMemberID)
        }
        switch role {
        case .administrator: return true
        case .kid: return false
        case .member:
            if item.task.assigneeIDs.isEmpty { return true }
            guard let memberRoles else { return false }
            return item.task.assigneeIDs.allSatisfy { memberRoles[$0] != nil && memberRoles[$0] != .kid }
        }
    }

    func canToggle(_ item: OwnTaskListItem) -> Bool {
        showsToggle(item) && !unresolvedTasks.contains(item.id)
    }

    /// The tap changes the checklist synchronously. One worker per task serializes writes, and
    /// checks the latest requested state after every response (SPEC-010 CA-08 / SPEC-011 CA-09).
    func toggle(_ item: OwnTaskListItem) {
        guard let current = items.first(where: { $0.id == item.id }), canToggle(current) else { return }
        desiredCompleted[item.id] = current.task.status != .completed
        intentRevisions[item.id, default: 0] += 1
        publishOptimisticState()
        lastChangedTaskID = item.id
        actionRevision += 1
        startProcessingIfNeeded(taskID: item.id)
    }

    func confirmMissionReopen() {
        guard let taskID = missionReopenTaskID, missionReopenPrompt != nil,
              !actionInFlight.contains(taskID) else { return }
        confirmedReopenIDs.insert(taskID)
        desiredCompleted[taskID] = false
        intentRevisions[taskID, default: 0] += 1
        publishOptimisticState()
        startProcessingIfNeeded(taskID: taskID)
    }

    func cancelMissionReopen() {
        missionReopenPrompt = nil
        missionReopenTaskID = nil
    }

    func dismissActionAlert() {
        actionAlert = nil
    }

    func refreshActionStatus() async {
        guard let taskID = actionFailureTaskID, !actionInFlight.contains(taskID) else { return }
        actionInFlight.insert(taskID)
        defer { actionInFlight.remove(taskID) }
        do {
            let latest = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
            mergeCanonical(latest)
            desiredCompleted.removeValue(forKey: taskID)
            unresolvedTasks.remove(taskID)
            actionFailureTaskID = unresolvedTasks.first
            actionFailure = actionFailureTaskID == nil ? nil : .needsRefresh
            actionAlert = nil
            await load()
            publishOptimisticState()
        } catch {
            actionFailure = .needsRefresh
            actionAlert = .uncertain
        }
    }

    private func startProcessingIfNeeded(taskID: UUID) {
        guard !actionInFlight.contains(taskID) else { return }
        actionInFlight.insert(taskID)
        Task { await processIntent(taskID: taskID) }
    }

    private func processIntent(taskID: UUID) async {
        defer { actionInFlight.remove(taskID) }
        var hasWritten = false
        while let canonical = canonicalTasks[taskID], let desired = desiredCompleted[taskID] {
            if desired == (canonical.status == .completed) {
                if hasWritten { await load() }
                // A second tap may have arrived while the final refresh was in flight.
                guard desired == desiredCompleted[taskID],
                      desired == (canonicalTasks[taskID]?.status == .completed) else { continue }
                desiredCompleted.removeValue(forKey: taskID)
                publishOptimisticState()
                if hasWritten {
                    lastChangedTaskID = taskID
                    actionRevision += 1
                }
                return
            }

            let commandRevision = intentRevisions[taskID, default: 0]
            do {
                let result: FamilyTask
                if desired {
                    result = try await completeTask.execute(taskID: taskID, accessToken: accessToken)
                    guard result.status == .completed else { throw TaskError.rejected }
                } else {
                    let confirm = confirmedReopenIDs.remove(taskID) != nil
                    result = try await reopenTask.execute(taskID: taskID, confirm: confirm, accessToken: accessToken)
                    guard result.status != .completed else { throw TaskError.rejected }
                    cancelMissionReopen()
                }
                hasWritten = true
                mergeCanonical(result)
            } catch TaskError.missionReopenRequiresConfirmation(let missions, let hasAcceptedReward) {
                if desiredCompleted[taskID] == false {
                    desiredCompleted.removeValue(forKey: taskID)
                    publishOptimisticState()
                    missionReopenTaskID = taskID
                    missionReopenPrompt = MissionReopenPrompt(
                        missionsAffected: missions, hasAcceptedReward: hasAcceptedReward
                    )
                }
                return
            } catch {
                guard await reconcileFailedCommand(taskID: taskID, error: error, commandRevision: commandRevision) else {
                    return
                }
                hasWritten = true
            }
        }
    }

    private func reconcileFailedCommand(taskID: UUID, error: Error, commandRevision: Int) async -> Bool {
        if case TaskError.notFound = error {
            desiredCompleted.removeValue(forKey: taskID)
            await load()
            if !loadFailed {
                publishOptimisticState()
                return false
            }
        }
        do {
            let latest = try await getTaskDetail.execute(taskID: taskID, accessToken: accessToken)
            mergeCanonical(latest)
            if desiredCompleted[taskID] == (latest.status == .completed) { return true }
            // A later tap is an explicit new intent; only it may initiate another write.
            if intentRevisions[taskID, default: 0] > commandRevision { return true }
            rollback(taskID: taskID, alert: .failed)
            return false
        } catch {
            let isDefinitive = switch error {
            case TaskError.actionNotAllowed, TaskError.rejected, TaskError.validationFailed:
                true
            default:
                false
            }
            rollback(taskID: taskID, alert: isDefinitive ? .failed : .uncertain)
            if !isDefinitive {
                unresolvedTasks.insert(taskID)
                actionFailureTaskID = taskID
                actionFailure = .needsRefresh
            }
            return false
        }
    }

    private func rollback(taskID: UUID, alert: TaskListActionAlert) {
        desiredCompleted.removeValue(forKey: taskID)
        confirmedReopenIDs.remove(taskID)
        cancelMissionReopen()
        publishOptimisticState()
        actionAlert = alert
        lastChangedTaskID = taskID
        actionRevision += 1
    }

    private func mergeCanonical(_ task: FamilyTask) {
        canonicalTasks[task.id] = task
        if let index = serverItems.firstIndex(where: { $0.id == task.id }) {
            let old = serverItems[index]
            serverItems[index] = OwnTaskListItem(
                task: task,
                displayStatus: task.status == .awaitingConfirmation && audience == .adult ? .pending : task.status
            )
            if (old.task.status == .completed) != (task.status == .completed), let previous = serverProgress {
                let change = task.status == .completed ? 1 : -1
                let completed = min(previous.total, max(0, previous.completed + change))
                serverProgress = DailyProgress(
                    total: previous.total, completed: completed,
                    percentage: previous.total == 0 ? nil : Double(completed) / Double(previous.total) * 100,
                    familyCreatedAt: previous.familyCreatedAt
                )
            }
        }
        publishOptimisticState()
    }

    private func publishOptimisticState() {
        items = serverItems.map { item in
            guard let desired = desiredCompleted[item.id], desired != (item.task.status == .completed) else {
                return item
            }
            let status: TaskStatus = desired ? .completed : .pending
            return OwnTaskListItem(task: Self.withStatus(item.task, status), displayStatus: status)
        }
        guard let serverProgress else { return }
        let adjustment = serverItems.reduce(0) { result, item in
            guard let desired = desiredCompleted[item.id], desired != (item.task.status == .completed) else {
                return result
            }
            return result + (desired ? 1 : -1)
        }
        if adjustment == 0 {
            progress = serverProgress
            return
        }
        let completed = min(serverProgress.total, max(0, serverProgress.completed + adjustment))
        progress = DailyProgress(
            total: serverProgress.total, completed: completed,
            percentage: serverProgress.total == 0 ? nil : Double(completed) / Double(serverProgress.total) * 100,
            familyCreatedAt: serverProgress.familyCreatedAt
        )
    }

    private static func withStatus(_ task: FamilyTask, _ status: TaskStatus) -> FamilyTask {
        FamilyTask(
            id: task.id, title: task.title, weight: task.weight, scheduledDate: task.scheduledDate,
            assigneeIDs: task.assigneeIDs, note: task.note, status: status,
            routineID: task.routineID, createdAt: task.createdAt
        )
    }

    private func loadMemberRolesIfNeeded() async {
        guard role == .member, items.contains(where: { $0.task.status != .completed && !$0.task.assigneeIDs.isEmpty }),
              let familyRepository else { return }
        do {
            var roles: [UUID: MemberRole] = [:]
            var cursor: String?
            var seenCursors = Set<String>()
            repeat {
                let page = try await familyRepository.listMembers(accessToken: accessToken, cursor: cursor)
                for member in page.items { roles[member.id] = member.role }
                cursor = page.nextCursor
                if let cursor, !seenCursors.insert(cursor).inserted { throw FamilyError.unavailable }
            } while cursor != nil
            memberRoles = roles
        } catch {
            memberRoles = nil
        }
    }

    /// Selecting an unavailable date is a no-op (CA-03): it never triggers a query.
    func selectDate(_ date: Date) async {
        let normalized = calendar.startOfDay(for: date)
        guard isDateAvailable(normalized), normalized != selectedDate else {
            return
        }
        selectedDate = normalized
        serverItems = []
        serverProgress = nil
        items = []
        progress = nil
        await load()
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: today())
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func displayStatusLabel(for item: OwnTaskListItem) -> LocalizedStringKey {
        switch item.displayStatus {
        case .pending: "tasks.personal.status.pending"
        case .awaitingConfirmation: "tasks.personal.status.awaitingConfirmation"
        case .completed: "tasks.detail.status_completed"
        }
    }

    private static func endOfCurrentMonth(from today: Date, calendar: Calendar) -> Date {
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let lastDay = calendar.date(bySetting: .day, value: range.upperBound - 1, of: today) else {
            return today
        }
        return calendar.startOfDay(for: lastDay)
    }

    private static func wireString(from date: Date) -> String {
        Self.wireFormatter.string(from: date)
    }

    private static func date(fromWire wire: String) -> Date? {
        Self.wireFormatter.date(from: wire)
    }

    private static var wireFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
