import SwiftUI

/// TEL-022 — criar/editar missão (SPEC-014 Fase 2). Empurrada, nunca sheet: mesma decisão de
/// 2026-10-19 já aplicada a TEL-013, para que o sheet .large do MOD-007 nunca empilhe sobre outro sheet.
struct MissionEditorView: View {
    @State private var viewModel: MissionEditorViewModel
    let missionRepository: any MissionRepository
    let taskRepository: any TaskRepository
    let routineRepository: any RoutineRepository
    let familyRepository: any FamilyRepository
    let accessToken: String
    let onSaved: () -> Void

    @State private var isDiscardConfirmationPresented = false
    @Environment(\.dismiss) private var dismiss

    /// Owns the view model via `@State` rather than taking a pre-built instance — same reasoning
    /// as `TaskEditorView`: `NavigationStack` can invoke this destination's builder more than once
    /// for the same push, and only `@State`'s storage survives that.
    init(
        mode: MissionEditorMode,
        repository: any MissionRepository,
        taskRepository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: any FamilyRepository,
        accessToken: String,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: MissionEditorViewModel(
            mode: mode,
            repository: repository,
            taskRepository: taskRepository,
            accessToken: accessToken
        ))
        self.missionRepository = repository
        self.taskRepository = taskRepository
        self.routineRepository = routineRepository
        self.familyRepository = familyRepository
        self.accessToken = accessToken
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("missions.detail.load_error", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("missions.common.retry") { Task { await viewModel.load() } }
                }
            } else {
                form
            }
        }
        .navigationTitle(viewModel.isEditing ? "missions.edit.title" : "missions.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if viewModel.hasUnsavedChanges {
                        isDiscardConfirmationPresented = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityIdentifier("missions.editor.back")
                .accessibilityLabel("Voltar")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isSaving {
                    ProgressView()
                        .accessibilityLabel("missions.form.submitting")
                } else {
                    Button {
                        Task { await viewModel.saveIfValid() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!viewModel.isFormValid)
                    .accessibilityIdentifier("missions.editor.save")
                    .accessibilityLabel("missions.form.submit")
                }
            }
        }
        .confirmationDialog(
            "Descartar alterações?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Descartar alterações", role: .destructive) { dismiss() }
            Button("Continuar editando", role: .cancel) {}
        } message: {
            Text("Os dados não salvos serão perdidos.")
        }
        .sheet(isPresented: $viewModel.isTaskPickerPresented) {
            MissionTaskPickerView(
                repository: missionRepository,
                taskRepository: taskRepository,
                routineRepository: routineRepository,
                familyRepository: familyRepository,
                accessToken: accessToken,
                initialSelection: viewModel.linkedTasks,
                onConfirm: { tasks in
                    viewModel.applyPickerSelection(tasks)
                }
            )
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.savedMission) { _, savedMission in
            if savedMission != nil {
                onSaved()
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("missions.form.title_placeholder", text: $viewModel.title)
                        .accessibilityIdentifier("missions.editor.title")
                    Text(Self.counterText(key: "missions.form.title_counter", count: viewModel.title.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let titleError = viewModel.titleError {
                    Text(titleError == .required ? "missions.form.error_title_required" : "missions.form.error_title_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("missions.editor.title_error")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("missions.form.note_placeholder", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityIdentifier("missions.editor.note")
                    Text(Self.counterText(key: "missions.form.note_counter", count: viewModel.note.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if viewModel.noteError != nil {
                    Text("missions.form.error_note_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("missions.editor.note_error")
                }
            }

            Section {
                tasksBlock
                if viewModel.showsTasksRequiredError {
                    Label("missions.form.error_tasks_required", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("missions.editor.tasks_error")
                }
            } header: {
                Text("missions.form.tasks_section_title")
            }

            if let banner = viewModel.banner {
                Section {
                    Text(bannerMessage(for: banner))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("missions.editor.banner")
                }
            }
        }
    }

    @ViewBuilder
    private var tasksBlock: some View {
        ForEach(viewModel.linkedTasks) { task in
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                Text(statusLabel(for: task.status))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        Button {
            viewModel.openTaskPicker()
        } label: {
            HStack {
                Text("missions.form.select_tasks_button")
                    .foregroundStyle(.primary)
                Spacer()
                if !viewModel.linkedTasks.isEmpty {
                    Text("\(viewModel.linkedTasks.count)")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("missions.editor.select_tasks")
    }

    private static func counterText(key: String.LocalizationValue, count: Int) -> String {
        String(format: String(localized: key), count)
    }

    /// Reusa as chaves de status já existentes em Tasks, mesmo texto de TEL-012/TEL-021.
    private func statusLabel(for status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "tasks.personal.status.pending")
        case .awaitingConfirmation: String(localized: "tasks.personal.status.awaitingConfirmation")
        case .completed: String(localized: "tasks.detail.status_completed")
        }
    }

    private func bannerMessage(for banner: MissionEditorBanner) -> LocalizedStringKey {
        switch banner {
        case .networkFailure:
            "missions.common.error_network"
        case .uncertainOutcome:
            "missions.common.error_uncertain"
        case .actionNotAllowed:
            "missions.common.error_action_not_allowed"
        case .completedProtected:
            "missions.edit.error_completed_protected"
        case .rejected:
            "missions.common.error_unavailable"
        }
    }
}
