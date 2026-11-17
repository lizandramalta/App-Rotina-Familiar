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
                    .tint(Color.App.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("tasks.detail.load_error", systemImage: "exclamationmark.triangle")
                        .font(.app(.title3))
                        .foregroundStyle(Color.App.Text.primary)
                } actions: {
                    Button { Task { await viewModel.load() } } label: {
                        Text("Tentar novamente")
                            .font(.app(.subtitleStrong))
                            .foregroundStyle(Color.App.Text.onAction)
                            .padding(.horizontal, AppSpacing.xxl)
                            .padding(.vertical, AppSpacing.md)
                            .appPrimaryPillSurface()
                    }
                    .buttonStyle(.plain)
                }
            } else {
                form
            }
        }
        .background(Color.App.Background.app.ignoresSafeArea())
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
                        .foregroundStyle(Color.App.Text.primary)
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
                    .tint(Color.App.Action.primary)
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

    /// TEL-013 high-fidelity layout (Figma 907:21922): stacked white cards on the app background.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                fieldsCard
                fieldErrors

                sectionHeader("tasks.form.weight_label")
                weightCard
                sectionFooter("tasks.form.weight_hint")

                sectionHeader("tasks.form.date_section_title")
                dateCard
                dateErrors

                // No footer here: the assignee explanation was dropped from TEL-013 and MOD-001 (UX-06).
                sectionHeader("tasks.form.assignees_label")
                assigneesCard

                if let banner = viewModel.banner {
                    Label(bannerMessage(for: banner), systemImage: "exclamationmark.triangle.fill")
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.System.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(.vertical, Self.rowVerticalPadding)
                        .appCard()
                        .accessibilityIdentifier("tasks.editor.banner")
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.App.Background.app.ignoresSafeArea())
    }

    // MARK: Cards

    /// Title and note share one card, with both counters below the note (UX-007 §5.1).
    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                TextField("tasks.form.title_placeholder", text: $viewModel.title)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                    .accessibilityIdentifier("tasks.editor.title")
                if viewModel.titleError != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.App.System.destructive)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Self.fieldVerticalPadding)
            separator
            TextField("tasks.form.note_placeholder", text: $viewModel.note, axis: .vertical)
                .lineLimit(1 ... 6)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.primary)
                .padding(.vertical, Self.fieldVerticalPadding)
                .accessibilityIdentifier("tasks.editor.note")
            HStack(spacing: Self.counterSpacing) {
                Spacer()
                Text(Self.counterText(key: "tasks.form.title_counter", count: viewModel.title.count))
                Text(Self.counterText(key: "tasks.form.note_counter", count: viewModel.note.count))
            }
            .font(.app(.caption))
            .foregroundStyle(Color.App.Text.secondary)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, Self.fieldsCardBottomPadding)
        .appCard()
    }

    @ViewBuilder
    private var fieldErrors: some View {
        if let titleError = viewModel.titleError {
            errorRow(titleError == .required ? "tasks.form.error_title_required" : "tasks.form.error_title_too_long")
                .accessibilityIdentifier("tasks.editor.title_error")
        }
        if viewModel.noteError != nil {
            errorRow("tasks.form.error_note_too_long")
                .accessibilityIdentifier("tasks.editor.note_error")
        }
    }

    private var weightCard: some View {
        let options: [(EffortWeight, LocalizedStringKey)] = [
            (.low, "tasks.form.weight_option_low"),
            (.medium, "tasks.form.weight_option_medium"),
            (.high, "tasks.form.weight_option_high"),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                if index > 0 { insetSeparator }
                selectableRow(option.1, isSelected: viewModel.weight == option.0) {
                    viewModel.weight = option.0
                }
            }
        }
        .appCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tasks.editor.weight")
    }

    private var dateCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("tasks.form.scheduled_date_label")
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer()
                DatePicker("tasks.form.scheduled_date_label", selection: $viewModel.scheduledDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.App.Action.primary)
                    .background(Color.App.Background.cardHighlight, in: RoundedRectangle(cornerRadius: AppSpacing.sm))
                    .disabled(viewModel.isScheduledDateLocked)
                    .accessibilityIdentifier("tasks.editor.scheduled_date")
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, Self.rowVerticalPadding)
            insetSeparator
            if viewModel.isEditing {
                // Read-only: editing never changes the recurrence (UX-008 §5.1, UX-05).
                HStack {
                    Text("routines.recurrence.title")
                        .foregroundStyle(Color.App.Text.primary)
                    Spacer()
                    Text(viewModel.editingRecurrenceSummary)
                        .foregroundStyle(Color.App.Text.secondary)
                }
                .font(.app(.body))
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.vertical, Self.rowVerticalPadding)
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
        }
        .appCard()
    }

    @ViewBuilder
    private var dateErrors: some View {
        if viewModel.startDateError {
            errorRow("routines.error_start_date_invalid")
                .accessibilityIdentifier("tasks.editor.start_date_error")
        }
        if viewModel.frequencyError {
            errorRow("routines.error_frequency_invalid")
                .accessibilityIdentifier("tasks.editor.frequency_error")
        }
    }

    private var assigneesCard: some View {
        Button {
            viewModel.isAssigneePickerPresented = true
        } label: {
            navigationRow(title: "tasks.form.assignees_row", value: assigneeSummary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("tasks.form.assignees_row")
        .accessibilityValue(Text(assigneeSummary))
        .accessibilityIdentifier("tasks.editor.assignees")
        .appCard()
    }

    // MARK: Building blocks

    private static let fieldVerticalPadding: CGFloat = 13
    private static let rowVerticalPadding: CGFloat = 15
    private static let fieldsCardBottomPadding: CGFloat = 10
    private static let counterSpacing: CGFloat = 14

    private var separator: some View {
        Rectangle().fill(Color.App.Border.separator).frame(height: 1)
    }

    private var insetSeparator: some View {
        separator.padding(.leading, AppSpacing.xxl)
    }

    /// Small secondary section title above a card, as in the prototype.
    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.app(.caption))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.leading, AppSpacing.xxl)
    }

    private func sectionFooter(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.app(.caption))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.horizontal, AppSpacing.xxl)
    }

    private func errorRow(_ key: LocalizedStringKey) -> some View {
        Label(key, systemImage: "exclamationmark.circle.fill")
            .font(.app(.caption))
            .foregroundStyle(Color.App.System.destructive)
            .padding(.leading, AppSpacing.xxl)
    }

    /// Single-choice row with a trailing check when selected (Figma "Alta / Linha selecionável").
    private func selectableRow(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.app(.bodyStrong))
                        .foregroundStyle(Color.App.Action.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, Self.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Tappable row in primary text with a trailing value and chevron (UX-007 §5.1).
    private func navigationRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.App.Text.primary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.App.Text.secondary)
            Image(systemName: "chevron.right")
                .font(.app(.noteStrong))
                .foregroundStyle(Color.App.Text.secondary)
        }
        .font(.app(.body))
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, Self.rowVerticalPadding)
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
