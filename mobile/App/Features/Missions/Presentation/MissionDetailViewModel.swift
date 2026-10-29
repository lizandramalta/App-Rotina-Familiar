import Foundation
import Observation

/// Backs TEL-021's minimal slice (SPEC-014 Fase 2): título, observação, tarefas vinculadas e
/// status. Progresso, participações e recompensa pertencem a SPEC-016/017 (fora de escopo).
@MainActor
@Observable
final class MissionDetailViewModel {
    private let missionID: UUID
    let role: MemberRole
    private let currentMemberID: UUID
    private let getMissionDetail: GetMissionDetailUseCase
    private let hydrateLinkedTasks: HydrateLinkedTasksUseCase
    private let accessToken: String

    private(set) var mission: Mission?
    private(set) var linkedTasks: [MissionTaskOption] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    init(
        missionID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        accessToken: String
    ) {
        self.missionID = missionID
        self.role = role
        self.currentMemberID = currentMemberID
        self.getMissionDetail = GetMissionDetailUseCase(repository: repository)
        self.hydrateLinkedTasks = HydrateLinkedTasksUseCase(taskRepository: taskRepository)
        self.accessToken = accessToken
    }

    /// Admin only, and only enquanto a missão está em andamento (UX-014 §5.4).
    var canEdit: Bool {
        role == .administrator && mission?.status == .inProgress
    }

    /// Kids só abrem suas próprias tarefas vinculadas; o toque numa tarefa de outra pessoa
    /// simplesmente não é oferecido (UX-014 §5.4, Figma "sem navegação").
    func canOpenTaskDetail(_ task: MissionTaskOption) -> Bool {
        guard role == .kid else { return true }
        return task.assigneeIDs.contains(currentMemberID)
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let mission = try await getMissionDetail.execute(missionID: missionID, accessToken: accessToken)
            // `mission`/`linkedTasks` are only committed once both calls succeed — if hydration
            // throws, `self.mission` must stay nil so the view renders the full-screen error state
            // instead of a mission with a silently empty task list (see Risco 2 da prévia técnica).
            let tasks = try await hydrateLinkedTasks.execute(taskIDs: mission.taskIDs, accessToken: accessToken)
            self.mission = mission
            self.linkedTasks = tasks
        } catch {
            loadFailed = true
        }
    }
}
