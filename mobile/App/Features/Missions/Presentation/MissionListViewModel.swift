import Foundation
import Observation

/// Backs TEL-020's minimal slice (SPEC-014 Fase 2) — title/status only, split into "Em andamento"
/// and "Concluídas". A single page is loaded, mirroring `DailyTaskListView`'s own list, which
/// likewise doesn't surface a "load more" control for this app's small, family-scoped lists.
@MainActor
@Observable
final class MissionListViewModel {
    private let listMissions: ListMissionsUseCase
    private let accessToken: String
    let role: MemberRole

    private(set) var inProgress: [MissionSummary] = []
    private(set) var completed: [MissionSummary] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    init(repository: any MissionRepository, role: MemberRole, accessToken: String) {
        self.listMissions = ListMissionsUseCase(repository: repository)
        self.role = role
        self.accessToken = accessToken
    }

    /// Only Administrador creates/edits missions (RN37) — Membro and Kids never see the action.
    var canCreate: Bool {
        role == .administrator
    }

    var isEmpty: Bool {
        inProgress.isEmpty && completed.isEmpty
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let page = try await listMissions.execute(cursor: nil, accessToken: accessToken)
            inProgress = page.items.filter { $0.status == .inProgress }
            completed = page.items.filter { $0.status == .completed }
        } catch {
            loadFailed = true
        }
    }
}
