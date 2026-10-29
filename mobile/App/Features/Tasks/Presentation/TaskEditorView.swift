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
        currentMemberID: UUID? = nil,
        onSaved: @escaping (FamilyTask) -> Void,
        onRoutineSaved: @escaping (Routine) -> Void
    ) {
        _viewModel = State(initialValue: TaskEditorViewModel(
            mode: mode,
            repository: repository,
            routineRepository: routineRepository,
            familyRepository: familyRepository,
            accessToken: accessToken,
            currentMemberID: currentMemberID
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
            // `.confirmationAction` renders the prominent filled ✓ circle of the prototype (UX-007 §5.1).
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                        .accessibilityLabel("tasks.form.submitting")
                } else {
                    Button {
                        Task { await viewModel.saveIfValid() }
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
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
            // One size, as in the prototype: scrolling moves the list, never resizes the sheet.
            AssigneePickerView(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
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
            // Quem faz shows names, not a count, so the family directory loads with the form.
            await viewModel.loadAssigneeCandidatesIfNeeded()
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
            // Title and note share one card, with both counters in its footer (UX-007 §5.1).
            Section {
                TextField("tasks.form.title_placeholder", text: $viewModel.title)
                    .accessibilityIdentifier("tasks.editor.title")
                VStack(alignment: .leading, spacing: 6) {
                    TextField("tasks.form.note_placeholder", text: $viewModel.note, axis: .vertical)
                        .lineLimit(1 ... 6)
                        .accessibilityIdentifier("tasks.editor.note")
                    HStack(spacing: 12) {
                        Spacer()
                        Text(Self.counterText(key: "tasks.form.title_counter", count: viewModel.title.count))
                        Text(Self.counterText(key: "tasks.form.note_counter", count: viewModel.note.count))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if let titleError = viewModel.titleError {
                    Text(titleError == .required ? "tasks.form.error_title_required" : "tasks.form.error_title_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.title_error")
                }
                if viewModel.noteError != nil {
                    Text("tasks.form.error_note_too_long")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("tasks.editor.note_error")
                }
            }

            Section {
                // The section header carries the visible "Esforço" title; the hidden label keeps
                // the picker named for VoiceOver.
                Picker("tasks.form.weight_label", selection: $viewModel.weight) {
                    Text("tasks.form.weight_option_low").tag(EffortWeight?.some(.low))
                    Text("tasks.form.weight_option_medium").tag(EffortWeight?.some(.medium))
                    Text("tasks.form.weight_option_high").tag(EffortWeight?.some(.high))
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("tasks.editor.weight")
            } header: {
                sectionHeader("tasks.form.weight_label")
            } footer: {
                Text("tasks.form.weight_hint")
                    .font(.footnote)
            }

            Section {
                DatePicker("tasks.form.scheduled_date_label", selection: $viewModel.scheduledDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .disabled(viewModel.isScheduledDateLocked)
                    .accessibilityIdentifier("tasks.editor.scheduled_date")
                if viewModel.isEditing {
                    // Read-only: editing never changes the recurrence (UX-008 §5.1, UX-05).
                    HStack {
                        Text("routines.recurrence.title")
                        Spacer()
                        Text(viewModel.editingRecurrenceSummary)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("tasks.editor.recurrence_readonly")
                } else {
                    Button {
                        Task { await viewModel.prepareRecurrencePicker() }
                    } label: {
                        navigationRow(title: "routines.recurrence.title", value: viewModel.recurrenceSummary)
                    }
                    .buttonStyle(.plain)
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
            } header: {
                sectionHeader("tasks.form.date_section_title")
            }

            // No footer here: the assignee explanation was dropped from TEL-013 and MOD-001 (UX-06).
            Section {
                Button {
                    viewModel.isAssigneePickerPresented = true
                } label: {
                    navigationRow(title: "tasks.form.assignees_row", value: assigneeSummary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("tasks.form.assignees_row")
                .accessibilityValue(Text(assigneeSummary))
                .accessibilityIdentifier("tasks.editor.assignees")
            } header: {
                sectionHeader("tasks.form.assignees_label")
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

    /// Small secondary section title, as in the prototype, instead of the large default header.
    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        // An explicit label color: `.secondary` inside a Form header is dimmed twice.
        Text(key)
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
    }

    /// Tappable row in primary text — a plain button style keeps the Form from tinting it with the
    /// accent color (UX-007 §5.1).
    private func navigationRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var assigneeSummary: String {
        if viewModel.assigneeIDs.isEmpty {
            return String(localized: "tasks.form.assignees_row_none")
        }
        let names = viewModel.orderedMembers
            .filter { viewModel.assigneeIDs.contains($0.id) }
            .map { viewModel.displayName(for: $0) }
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
        case .routineSourceInvalid:
            "routines.error_source_task_invalid"
        }
    }
}
