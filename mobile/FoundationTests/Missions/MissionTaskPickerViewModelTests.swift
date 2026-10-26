import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct MissionTaskPickerViewModelTests {
    private func makeOption(id: UUID = UUID(), title: String) -> MissionTaskOption {
        MissionTaskOption(id: id, title: title, weight: .medium, scheduledDate: "2026-10-10", status: .pending, assigneeIDs: [])
    }

    @Test("Toggling a task updates the selection and confirmedSelection preserves selection order")
    func toggleUpdatesSelection() async {
        let first = makeOption(title: "Arrumar o quintal")
        let second = makeOption(title: "Lavar a louça")
        let repository = MissionRepositorySpy(taskOptionsResult: .success(
            MissionTaskOptionPage(items: [first, second], nextCursor: nil)
        ))
        let viewModel = MissionTaskPickerViewModel(repository: repository, accessToken: "token", initialSelection: [])
        await viewModel.load()

        viewModel.toggle(second)
        viewModel.toggle(first)

        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.confirmedSelection().map(\.id) == [second.id, first.id])

        viewModel.toggle(second)
        #expect(viewModel.confirmedSelection().map(\.id) == [first.id])
    }

    @Test("MOD-007 never blocks confirming an empty selection (UX-014 §5.2) — TEL-022 alone blocks on empty")
    func confirmingEmptySelectionIsAllowed() {
        let viewModel = MissionTaskPickerViewModel(repository: MissionRepositorySpy(), accessToken: "token", initialSelection: [])
        #expect(viewModel.confirmedSelection().isEmpty)
    }

    @Test("A task selected under a previous search is not dropped when a new search no longer returns it")
    func selectionSurvivesNarrowerSearch() async {
        let selected = makeOption(title: "Arrumar o quintal")
        let repository = MissionRepositorySpy()
        let viewModel = MissionTaskPickerViewModel(repository: repository, accessToken: "token", initialSelection: [selected])

        repository.setTaskOptionsResult(.success(MissionTaskOptionPage(items: [makeOption(title: "Lavar a louça")], nextCursor: nil)))
        viewModel.query = "lavar"
        await viewModel.load()

        #expect(viewModel.selectedCount == 1)
        #expect(viewModel.confirmedSelection().map(\.id) == [selected.id])
        #expect(viewModel.options.contains { $0.id == selected.id })
    }

    @Test("CA-18: a task created via '+ Nova tarefa' is prepended and pre-selected")
    func prependAndSelectPutsNewTaskFirst() {
        let existing = makeOption(title: "Arrumar o quintal")
        let viewModel = MissionTaskPickerViewModel(repository: MissionRepositorySpy(), accessToken: "token", initialSelection: [])
        viewModel.toggle(existing)

        let created = makeOption(title: "Tirar o lixo")
        viewModel.prependAndSelect(created)

        #expect(viewModel.options.first?.id == created.id)
        #expect(viewModel.isSelected(created))
        #expect(viewModel.selectedCount == 2)
    }

    @Test("Passes the current query to the repository, nil when empty")
    func loadForwardsQuery() async {
        let repository = MissionRepositorySpy()
        let viewModel = MissionTaskPickerViewModel(repository: repository, accessToken: "token", initialSelection: [])

        await viewModel.load()
        viewModel.query = "quintal"
        await viewModel.load()

        #expect(repository.taskOptionsCalls == [nil, "quintal"])
    }
}
