import Foundation
import Observation

/// Backs MOD-007 (SPEC-014 Fase 2, CA-18). Edits a local draft; nothing is written back to
/// TEL-022 until Confirmar is tapped. Confirmar is always enabled, even with an empty selection
/// (UX-014 §5.2) — the "sem tarefas" block is TEL-022's Salvar alone (see Risco 1 da prévia técnica).
@MainActor
@Observable
final class MissionTaskPickerViewModel {
    private let getTaskOptions: GetMissionTaskOptionsUseCase
    private let accessToken: String

    var query = ""
    private(set) var options: [MissionTaskOption] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// Mantido separado de `options`: uma tarefa selecionada numa busca anterior não pode
    /// desaparecer da seleção só porque a busca atual não a traz mais nos resultados visíveis.
    private var selectedTasks: [UUID: MissionTaskOption]
    private var selectionOrder: [UUID]
    private var searchTask: Task<Void, Never>?

    init(repository: any MissionRepository, accessToken: String, initialSelection: [MissionTaskOption]) {
        self.getTaskOptions = GetMissionTaskOptionsUseCase(repository: repository)
        self.accessToken = accessToken
        self.selectedTasks = Dictionary(uniqueKeysWithValues: initialSelection.map { ($0.id, $0) })
        self.selectionOrder = initialSelection.map(\.id)
        self.options = initialSelection
    }

    var selectedCount: Int {
        selectedTasks.count
    }

    func isSelected(_ task: MissionTaskOption) -> Bool {
        selectedTasks[task.id] != nil
    }

    func toggle(_ task: MissionTaskOption) {
        if selectedTasks.removeValue(forKey: task.id) != nil {
            selectionOrder.removeAll { $0 == task.id }
        } else {
            selectedTasks[task.id] = task
            selectionOrder.append(task.id)
        }
    }

    func confirmedSelection() -> [MissionTaskOption] {
        selectionOrder.compactMap { selectedTasks[$0] }
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let page = try await getTaskOptions.execute(
                query: query.isEmpty ? nil : query,
                cursor: nil,
                accessToken: accessToken
            )
            let selected = selectionOrder.compactMap { selectedTasks[$0] }
            var seen = Set(selectionOrder)
            var merged = selected
            for item in page.items where !seen.contains(item.id) {
                merged.append(item)
                seen.insert(item.id)
            }
            options = merged
        } catch {
            loadFailed = true
        }
    }

    /// Debounced so each keystroke in `.searchable` doesn't fire its own request.
    func search() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    /// CA-18: a tarefa recém-criada por "+ Nova tarefa" aparece pré-selecionada no topo da lista.
    func prependAndSelect(_ task: MissionTaskOption) {
        options.removeAll { $0.id == task.id }
        options.insert(task, at: 0)
        selectedTasks[task.id] = task
        selectionOrder.removeAll { $0 == task.id }
        selectionOrder.append(task.id)
    }
}
