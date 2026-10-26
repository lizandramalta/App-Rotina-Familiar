import SwiftUI

/// TEL-012 — Editar/Excluir (Admin/Membro only) and Reabrir (Admin/Membro always, Kids on
/// their own task — SPEC-011). Adult routine occurrences show their origin and materialization
/// state; routine management waits for MOD-003 in SPEC-008 Fase 2.
struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    @AccessibilityFocusState private var isMissionWarningFocused: Bool
    @AccessibilityFocusState private var isStatusFocused: Bool
    let onRequestEdit: () -> Void
    let onDeleted: () -> Void
    let onCompleted: () -> Void
    let onReopened: () -> Void

    /// Owns the view model via `@State` rather than taking a pre-built instance: `NavigationStack`
    /// can invoke this destination's builder more than once for the same push (observed via
    /// XCUITest), and only `@State`'s storage — keyed by this view's identity, not by how many
    /// times `init` runs — survives that so `load()` isn't abandoned mid-flight by a replacement.
    init(
        taskID: UUID,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any TaskRepository,
        routineRepository: any RoutineRepository,
        familyRepository: (any FamilyRepository)? = nil,
        accessToken: String,
        onRequestEdit: @escaping () -> Void,
        onDeleted: @escaping () -> Void,
        onCompleted: @escaping () -> Void = {},
        onReopened: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: TaskDetailViewModel(
            taskID: taskID,
            role: role,
            currentMemberID: currentMemberID,
            repository: repository,
            routineRepository: routineRepository,
            familyRepository: familyRepository,
            accessToken: accessToken
        ))
        self.onRequestEdit = onRequestEdit
        self.onDeleted = onDeleted
        self.onCompleted = onCompleted
        self.onReopened = onReopened
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
            } else if let task = viewModel.task {
                content(for: task)
            } else {
                // Keeps the Group's branch always non-empty before `load()` sets `isLoading`.
                Color.clear
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.task != nil, viewModel.canManageTask, viewModel.task?.routineID == nil {
                    Button("Editar", action: onRequestEdit)
                        .accessibilityIdentifier("tasks.detail.edit")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.missionReopenPrompt != nil },
            set: { isPresented in if !isPresented { viewModel.cancelMissionReopen() } }
        )) {
            if let prompt = viewModel.missionReopenPrompt {
                MissionReopenConfirmationView(
                    prompt: prompt,
                    role: viewModel.role,
                    isSubmitting: viewModel.isReopening,
                    isWarningFocused: $isMissionWarningFocused,
                    onConfirm: { Task { await viewModel.confirmMissionReopen() } },
                    onCancel: { viewModel.cancelMissionReopen() }
                )
            }
        }
        .confirmationDialog(
            "tasks.delete.confirm_message",
            isPresented: $viewModel.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) { Task { await viewModel.confirmDelete() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if viewModel.hasPendingSignal {
                Text("tasks.delete.pending_signal_notice")
            }
        }
        .alert(
            "tasks.detail.mission_protected_title",
            isPresented: Binding(
                get: { viewModel.deleteBlock != nil },
                set: { isPresented in if !isPresented { viewModel.dismissDeleteBlock() } }
            )
        ) {
            Button("OK") { viewModel.dismissDeleteBlock() }
        } message: {
            Text(deleteBlockMessageKey)
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                onDeleted()
            }
        }
        .onChange(of: viewModel.completionRevision) { _, revision in
            if revision > 0 {
                onCompleted()
                isStatusFocused = true
            }
        }
        .onChange(of: viewModel.showReopenSuccessBanner) { _, isShown in
            if isShown {
                onReopened()
                isStatusFocused = true
            }
        }
    }

    @ViewBuilder
    private func content(for task: FamilyTask) -> some View {
        GeometryReader { geometry in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title3.weight(.semibold))
                        statusBadge(for: task.status)
                            .accessibilityFocused($isStatusFocused)
                            .accessibilityIdentifier("tasks.detail.status")
                    }
                    .padding(.vertical, 4)
                }

                if viewModel.showReopenSuccessBanner {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.primary)
                                .accessibilityHidden(true)
                            Text("task.reopen.success_banner")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    row(label: "tasks.form.weight_label", value: weightLabel(task.weight))
                    row(label: "tasks.form.scheduled_date_label", value: task.scheduledDate)
                    row(label: "tasks.form.assignees_label", value: assigneeSummary(task))
                    if let routine = viewModel.routine {
                        row(label: "routines.recurrence.title", value: frequencyLabel(routine.frequency))
                    }
                }

                if viewModel.role != .kid, task.routineID != nil {
                    Section {
                        if viewModel.routine?.materializationState == .pending {
                            Label("routines.materialization.preparing", systemImage: "clock")
                                .accessibilityIdentifier("routines.detail.preparing")
                        }
                        if viewModel.routineLoadFailed {
                            Label("routines.error_unavailable", systemImage: "exclamationmark.triangle")
                            Button("tasks.error.retry") { Task { await viewModel.refreshRoutine() } }
                        }
                        Text("routines.detail.origin_hint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let note = task.note, !note.isEmpty {
                    Section("tasks.detail.note_label") {
                        Text(note)
                    }
                }

                if let banner = viewModel.banner {
                    Section {
                        Text(banner == .loadFailed ? "tasks.detail.load_error" : "tasks.common.error_unavailable")
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.reopenFailed {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("tasks.common.error_unavailable")
                                .foregroundStyle(.red)
                            Button("Tentar novamente") { Task { await viewModel.requestReopen() } }
                        }
                    }
                }

                if viewModel.memberRolesLoadFailed, task.status != .completed {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("task.complete.members_unavailable")
                                .foregroundStyle(.secondary)
                            Button("tasks.error.retry") { Task { await viewModel.retryMemberRoles() } }
                        }
                    }
                }

                if let failure = viewModel.completionFailure {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(completionFailureMessageKey(for: failure))
                                .foregroundStyle(.secondary)
                            if failure == .needsRefresh {
                                Button("task.complete.refresh_status") {
                                    Task { await viewModel.refreshCompletionStatus() }
                                }
                                .disabled(viewModel.isCompleting)
                                .accessibilityIdentifier("tasks.detail.complete.refresh")
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                }

                if viewModel.showsCompleteAction {
                    Section {
                        Button {
                            Task { await viewModel.requestComplete() }
                        } label: {
                            Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button")
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: Capsule())
                        .disabled(!viewModel.canComplete)
                        .opacity(viewModel.canComplete ? 1 : 0.5)
                        .accessibilityIdentifier("tasks.detail.complete")
                        .accessibilityLabel(Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button"))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if viewModel.canReopen {
                    Section {
                        Button {
                            Task { await viewModel.requestReopen() }
                        } label: {
                            Text(viewModel.isReopening ? "task.reopen.pending" : "task.reopen.button")
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .background(.background, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color(uiColor: .separator), lineWidth: 1))
                        .disabled(viewModel.isReopening)
                        .accessibilityIdentifier("tasks.detail.reopen")
                        .accessibilityLabel(Text("task.reopen.accessibilityLabel"))
                        .accessibilityHint(Text("task.reopen.accessibilityHint"))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if viewModel.canManageTask, task.routineID == nil {
                    Section {
                        if viewModel.canDeleteDirectly {
                            Button(role: .destructive) { viewModel.requestDelete() } label: {
                                Text("Excluir")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .background(.background, in: Capsule())
                            .disabled(viewModel.isDeleting)
                            .accessibilityIdentifier("tasks.detail.delete")
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Excluir")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(.background, in: Capsule())
                                    .foregroundStyle(.red.opacity(0.5))
                                Text("tasks.delete.error_already_completed")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("tasks.detail.delete_disabled")
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .frame(maxWidth: geometry.size.width >= 1100 ? 734 : 580)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private var deleteBlockMessageKey: LocalizedStringKey {
        viewModel.deleteBlock == .alreadyCompleted
            ? "tasks.delete.error_already_completed"
            : "tasks.delete.error_mission_protected"
    }

    private func completionFailureMessageKey(for failure: TaskCompletionFailure) -> LocalizedStringKey {
        failure == .needsRefresh
            ? "task.complete.error_unconfirmed"
            : "task.complete.still_pending"
    }

    private func row(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(for status: TaskStatus) -> some View {
        let (key, icon): (LocalizedStringKey, String) = switch status {
        case .pending: ("tasks.detail.status_pending", "circle")
        case .awaitingConfirmation: ("tasks.detail.status_awaiting_confirmation", "clock")
        case .completed: ("tasks.detail.status_completed", "checkmark.circle.fill")
        }
        return Label(key, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func weightLabel(_ weight: EffortWeight) -> String {
        switch weight {
        case .low: String(localized: "tasks.form.weight_option_low")
        case .medium: String(localized: "tasks.form.weight_option_medium")
        case .high: String(localized: "tasks.form.weight_option_high")
        }
    }

    private func frequencyLabel(_ frequency: RoutineFrequency) -> String {
        if frequency == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), frequency.rawValue)
    }

    private func assigneeSummary(_ task: FamilyTask) -> String {
        task.assigneeIDs.isEmpty ? String(localized: "tasks.form.assignees_none") : "\(task.assigneeIDs.count)"
    }
}
