import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MissionListViewModelTests {
    private func makeSummary(title: String, status: MissionStatus) -> MissionSummary {
        MissionSummary(id: UUID(), title: title, status: status, taskCount: 2, completedTaskCount: status == .completed ? 2 : 0)
    }

    @Test("RN37: only Administrador sees the 'Nova missão' action")
    func onlyAdminCanCreate() {
        let admin = MissionListViewModel(repository: MissionRepositorySpy(), role: .administrator, accessToken: "token")
        let member = MissionListViewModel(repository: MissionRepositorySpy(), role: .member, accessToken: "token")
        let kid = MissionListViewModel(repository: MissionRepositorySpy(), role: .kid, accessToken: "token")

        #expect(admin.canCreate)
        #expect(!member.canCreate)
        #expect(!kid.canCreate)
    }

    @Test("Splits missions into 'Em andamento' and 'Concluídas' sections")
    func loadSplitsBySections() async {
        let inProgress = makeSummary(title: "Casa pronta para o fim de semana", status: .inProgress)
        let completed = makeSummary(title: "Semana organizada", status: .completed)
        let repository = MissionRepositorySpy(missionsResult: .success(MissionPage(items: [inProgress, completed], nextCursor: nil)))
        let viewModel = MissionListViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.inProgress.map(\.id) == [inProgress.id])
        #expect(viewModel.completed.map(\.id) == [completed.id])
        #expect(!viewModel.isEmpty)
    }

    @Test("An empty page is reflected as the empty state")
    func emptyPage() async {
        let repository = MissionRepositorySpy(missionsResult: .success(MissionPage(items: [], nextCursor: nil)))
        let viewModel = MissionListViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.isEmpty)
    }

    @Test("A load failure is surfaced without crashing")
    func loadFailure() async {
        let repository = MissionRepositorySpy(missionsResult: .failure(MissionError.unavailable))
        let viewModel = MissionListViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.loadFailed)
        #expect(viewModel.isEmpty)
    }
}
