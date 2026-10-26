import SwiftUI

/// TEL-013 (task or routine creation). Pushed onto the "Minhas tarefas" stack — never a sheet,
/// per the 2026-10-19 design decision: chevron back, inline title, ✓ Salvar trailing.
struct TaskEditorView: View {
    @State private var viewModel: TaskEditorViewModel
    let onSaved: (FamilyTask) -> Void
    let onRoutineSaved: (Routine) -> Void

    @State private var isDiscardConfirmationPresented = false
    @Environment(\.dismiss) private var dismiss

    /// Owns the view model via `@State` rather than taking a pre-built instance: `NavigationStack`
    /// can invoke this destination's builder more than once for the same push, and only `@State`'s
    /// storage — keyed by this view's identity, not by how many times `init` runs — survives that
    /// (same issue confirmed for `TaskDetailView` via XCUITest; guarded against here too).
    init(
        mode: TaskEditorMode,
        repository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: any FamilyRepository,
        accessToken: String,
        onSaved: @escaping (FamilyTask) -> Void,
        onRoutineSaved: @escaping (Routine) -> Void
    ) {
        _viewModel = State(initialValue: TaskEditorViewModel(
            mode: mode,
            repository: repository,
            routineRepository: routineRepository,
            familyRepository: familyRepository,
            accessToken: accessToken
        ))
        self.onSaved = onSaved
        self.onRoutineSaved = onRoutineSaved
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("tasks.detail.load_error", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Tentar novamente") { Task { await viewModel.load() } }
                }
            } else {
                form
            }
        }
        .navigationTitle(viewModel.isEditing ? "tasks.edit.title" : "tasks.create.title")
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
                .accessibilityIdentifier("tasks.editor.back")
                .accessibilityLabel("Voltar")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isSaving {
                    ProgressView()
                        .accessibilityLabel("tasks.form.submitting")
                } else {
                    Button {
                        Task { await viewModel.saveIfValid() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!viewModel.isFormValid)
                    .accessibilityIdentifier("tasks.editor.save")
                    .accessibilityLabel("tasks.form.submit")
                }
            }
        }
        .confirmationDialog(
            "tasks.form.discard_title",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Descartar alterações", role: .destructive) { dismiss() }
            Button("Continuar editando", role: .cancel) {}
        } message: {
            Text("tasks.form.discard_message")
        }
        .sheet(isPresented: $viewModel.isAssigneePickerPresented) {
            AssigneePickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isSignalResolutionPresented) {
            SignalResolutionView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isRecurrencePickerPresented) {
            RecurrencePickerView(startDate: viewModel.scheduledDate, frequency: viewModel.frequency) { date, frequency in
                viewModel.setRecurrence(startDate: date, frequency: frequency)
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.savedTask) { _, savedTask in
            if let savedTask {
                onSaved(savedTask)
            }
        }
        .onChange(of: viewModel.savedRoutine) { _, savedRoutine in
            if let savedRoutine { onRoutineSaved(savedRoutine) }
        }
    }

    @ViewBuilder
    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("tasks.form.title_placeholder", text: $viewModel.title)
                        .accessibilityIdentifier("tasks.editor.title")
                    Text(Self.counterText(key: "tasks.form.title_counter", count: viewModel.title.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let titleError = viewModel.titleError {
                    Text(titleError == .required ? "tasks.form.error_title_required" : "tasks.form.error_title_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.title_error")
                }
            }

            Section {
                Picker("tasks.form.weight_label", selection: $viewModel.weight) {
                    Text("tasks.form.weight_option_low").tag(EffortWeight?.some(.low))
                    Text("tasks.form.weight_option_medium").tag(EffortWeight?.some(.medium))
                    Text("tasks.form.weight_option_high").tag(EffortWeight?.some(.high))
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("tasks.editor.weight")
            }

            Section {
                DatePicker("tasks.form.scheduled_date_label", selection: $viewModel.scheduledDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("tasks.editor.scheduled_date")
                if !viewModel.isEditing {
                    Button {
                        Task { await viewModel.prepareRecurrencePicker() }
                    } label: {
                        HStack {
                            Text("routines.recurrence.title")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.recurrenceSummary)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("routines.recurrence.title")
                    .accessibilityValue(Text(viewModel.recurrenceSummary))
                    .accessibilityIdentifier("tasks.editor.recurrence")
                }
                if viewModel.startDateError {
                    Text("routines.error_start_date_invalid")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.start_date_error")
                }
                if viewModel.frequencyError {
                    Text("routines.error_frequency_invalid")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.frequency_error")
                }
            }

            Section {
                Button {
                    viewModel.isAssigneePickerPresented = true
                } label: {
                    HStack {
                        Text("tasks.form.assignees_label")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(assigneeSummary)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("tasks.editor.assignees")
            } footer: {
                Text("tasks.form.assignees_footer")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("tasks.form.note_placeholder", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .accessibilityIdentifier("tasks.editor.note")
                    Text(Self.counterText(key: "tasks.form.note_counter", count: viewModel.note.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if viewModel.noteError != nil {
                    Text("tasks.form.error_note_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.note_error")
                }
            }

            if let banner = viewModel.banner {
                Section {
                    Text(bannerMessage(for: banner))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.banner")
                }
            }
        }
    }

    private var assigneeSummary: String {
        if viewModel.assigneeIDs.isEmpty {
            return String(localized: "tasks.form.assignees_none")
        }
        let names = viewModel.availableMembers
            .filter { viewModel.assigneeIDs.contains($0.id) }
            .map(\.name)
        return names.isEmpty ? "\(viewModel.assigneeIDs.count)" : names.joined(separator: ", ")
    }

    private static func counterText(key: String.LocalizationValue, count: Int) -> String {
        String(format: String(localized: key), count)
    }

    private func bannerMessage(for banner: TaskEditorBanner) -> LocalizedStringKey {
        switch banner {
        case .networkFailure:
            "tasks.common.error_network"
        case .uncertainOutcome:
            "tasks.common.error_uncertain"
        case .actionNotAllowed:
            "tasks.common.error_action_not_allowed"
        case .missionProtected:
            "tasks.delete.error_mission_protected"
        case .rejected:
            "tasks.common.error_unavailable"
        case .routineUnavailable:
            "routines.error_unavailable"
        case .routineUncertainOutcome:
            "routines.error_result_uncertain"
        }
    }
}
