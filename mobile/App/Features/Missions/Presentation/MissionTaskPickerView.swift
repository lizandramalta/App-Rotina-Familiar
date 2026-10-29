import SwiftUI

/// Typed destination pushed only inside MOD-007's own `NavigationStack` — never a second sheet.
nonisolated private enum MissionTaskPickerRoute: Hashable {
    case createTask
}

/// MOD-007 — selecionar tarefas da missão (SPEC-014 Fase 2). `.sheet(.large)` sobre TEL-022, com
/// `NavigationStack` próprio para poder empurrar TEL-013 ao tocar "+ Nova tarefa" sem empilhar um
/// segundo sheet (CA-18, decisão de 2026-10-19 já aplicada a TEL-013/TEL-022).
struct MissionTaskPickerView: View {
    @State private var viewModel: MissionTaskPickerViewModel
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let familyRepository: any FamilyRepository
    let accessToken: String
    let onConfirm: ([MissionTaskOption]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [MissionTaskPickerRoute] = []

    init(
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: any FamilyRepository,
        accessToken: String,
        initialSelection: [MissionTaskOption],
        onConfirm: @escaping ([MissionTaskOption]) -> Void
    ) {
        _viewModel = State(initialValue: MissionTaskPickerViewModel(
            repository: repository,
            accessToken: accessToken,
            initialSelection: initialSelection
        ))
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.familyRepository = familyRepository
        self.accessToken = accessToken
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("missions.task_picker.title")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("missions.task_picker.search_placeholder"))
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.search()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityIdentifier("missions.task_picker.close")
                        .accessibilityLabel(Text("missions.task_picker.close_label"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onConfirm(viewModel.confirmedSelection())
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityIdentifier("missions.task_picker.confirm")
                        .accessibilityLabel(Text("missions.task_picker.confirm_label"))
                    }
                }
                .navigationDestination(for: MissionTaskPickerRoute.self) { route in
                    switch route {
                    case .createTask:
                        TaskEditorView(
                            mode: .create,
                            repository: taskRepository,
                            routineRepository: routineRepository,
                            familyRepository: familyRepository,
                            accessToken: accessToken,
                            onSaved: { createdTask in
                                viewModel.prependAndSelect(MissionTaskOption(familyTask: createdTask))
                                path.removeAll()
                            },
                            // Mission linking has nothing to do with recurrence (SPEC-008 belongs
                            // to TEL-013's own flow); a routine created here still has no concrete
                            // task to link, so it's simply not selected back into the mission draft.
                            onRoutineSaved: { _ in path.removeAll() }
                        )
                    }
                }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.options.isEmpty {
            ProgressView()
        } else if viewModel.loadFailed, viewModel.options.isEmpty {
            failureState
        } else {
            VStack(spacing: 0) {
                Button {
                    path.append(.createTask)
                } label: {
                    Label("missions.task_picker.add_new_task", systemImage: "plus")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("missions.task_picker.add_new_task")

                if viewModel.options.isEmpty {
                    emptyState
                } else {
                    Text(Self.selectionSummary(count: viewModel.selectedCount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .accessibilityIdentifier("missions.task_picker.selection_summary")

                    List(viewModel.options) { task in
                        row(for: task)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func row(for task: MissionTaskOption) -> some View {
        let isSelected = viewModel.isSelected(task)
        return Button {
            viewModel.toggle(task)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .foregroundStyle(.primary)
                    Text(statusLabel(for: task.status))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(task.title), \(statusLabel(for: task.status)), \(isSelected ? String(localized: "missions.task_picker.selected") : String(localized: "missions.task_picker.not_selected"))"))
        .accessibilityIdentifier("missions.task_picker.row.\(task.id.uuidString)")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("missions.task_picker.empty_title", systemImage: "magnifyingglass")
        } description: {
            Text("missions.task_picker.empty_description")
        }
        .accessibilityIdentifier("missions.task_picker.empty")
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("missions.task_picker.load_error", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("missions.common.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("missions.task_picker.load_error")
    }

    private func statusLabel(for status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "tasks.personal.status.pending")
        case .awaitingConfirmation: String(localized: "tasks.personal.status.awaitingConfirmation")
        case .completed: String(localized: "tasks.detail.status_completed")
        }
    }

    private static func selectionSummary(count: Int) -> String {
        count == 0
            ? String(localized: "missions.task_picker.none_selected")
            : String(format: String(localized: "missions.task_picker.selected_count"), count)
    }
}
