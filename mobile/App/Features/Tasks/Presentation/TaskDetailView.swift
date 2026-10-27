import SwiftUI

/// TEL-012 — Editar/Excluir (Admin/Membro only) and Reabrir (Admin/Membro always, Kids on
/// their own task — SPEC-011). On a routine occurrence, Editar and Excluir first ask the scope in
/// MOD-003 (SPEC-008 Fase 2, UX-008 §5.4).
struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    private let currentMemberID: UUID
    @AccessibilityFocusState private var isMissionWarningFocused: Bool
    @AccessibilityFocusState private var isStatusFocused: Bool
    /// `nil` for a single task; the scope chosen in MOD-003 for a routine occurrence.
    let onRequestEdit: (RoutineScope?) -> Void
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
        onRequestEdit: @escaping (RoutineScope?) -> Void,
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
        self.currentMemberID = currentMemberID
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.task != nil, viewModel.canManageTask {
                    Button("Editar") {
                        if viewModel.requestEdit() { onRequestEdit(nil) }
                    }
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
        .sheet(isPresented: Binding(
            get: { viewModel.scopePrompt != nil },
            set: { isPresented in if !isPresented { viewModel.scopePrompt = nil } }
        )) {
            if let purpose = viewModel.scopePrompt {
                RoutineScopeSheetView(purpose: purpose, summary: viewModel.scopeSummary) { scope in
                    switch purpose {
                    case .edit:
                        viewModel.scopePrompt = nil
                        onRequestEdit(scope)
                    case .delete:
                        viewModel.chooseDeleteScope(scope)
                    }
                }
            }
        }
        .alert(
            "tasks.delete.confirm_message",
            isPresented: $viewModel.isConfirmingDelete
        ) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) { Task { await viewModel.confirmDelete() } }
        } message: {
            if viewModel.pendingDeleteScope == .thisAndFuture {
                Text("\(viewModel.task?.title ?? "")\n\n\(String(localized: "routines.scope.selected_and_future_hint"))")
            } else if viewModel.hasPendingSignal {
                Text("\(viewModel.task?.title ?? "")\n\n\(String(localized: "tasks.delete.pending_signal_notice"))")
            } else if let task = viewModel.task {
                Text(task.title)
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

    private func content(for task: FamilyTask) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(task.title)
                            .font(.title.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusBadge(for: displayedStatus(for: task))
                            .accessibilityFocused($isStatusFocused)
                            .accessibilityIdentifier("tasks.detail.status")
                    }
                    .padding(.horizontal, 4)

                    if viewModel.showReopenSuccessBanner {
                        Label("task.reopen.success_banner", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    }

                    detailsCard(for: task)

                    if viewModel.role != .kid,
                       task.routineID != nil,
                       viewModel.routine?.materializationState == .pending || viewModel.routineLoadFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.routine?.materializationState == .pending {
                                Label("routines.materialization.preparing", systemImage: "clock")
                                    .accessibilityIdentifier("routines.detail.preparing")
                            }
                            if viewModel.routineLoadFailed {
                                Label("routines.error_unavailable", systemImage: "exclamationmark.triangle")
                                Button("tasks.error.retry") { Task { await viewModel.refreshRoutine() } }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    }

                    if let note = task.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("tasks.detail.note_label")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                            Text(note)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(.background, in: RoundedRectangle(cornerRadius: 26))
                        }
                    }

                    if let banner = viewModel.banner {
                        Text(bannerMessageKey(banner))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.reopenFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("tasks.common.error_unavailable")
                                .foregroundStyle(.red)
                            Button("Tentar novamente") { Task { await viewModel.requestReopen() } }
                        }
                    }

                    if viewModel.memberDirectoryLoadFailed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("tasks.detail.assignees_unavailable")
                                .foregroundStyle(.secondary)
                            Button("tasks.error.retry") { Task { await viewModel.retryMemberRoles() } }
                        }
                    }

                    if let failure = viewModel.completionFailure {
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

                    VStack(spacing: 10) {
                        if viewModel.showsCompleteAction {
                            Button {
                                Task { await viewModel.requestComplete() }
                            } label: {
                                Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: Capsule())
                            .disabled(!viewModel.canComplete)
                            .opacity(viewModel.canComplete ? 1 : 0.5)
                            .accessibilityIdentifier("tasks.detail.complete")
                            .accessibilityLabel(Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button"))
                        }

                        if viewModel.canReopen {
                            Button {
                                Task { await viewModel.requestReopen() }
                            } label: {
                                Text(viewModel.isReopening ? "task.reopen.pending" : "task.reopen.button")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            .background(.background, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color(uiColor: .separator), lineWidth: 1))
                            .disabled(viewModel.isReopening)
                            .accessibilityIdentifier("tasks.detail.reopen")
                            .accessibilityLabel(Text("task.reopen.accessibilityLabel"))
                            .accessibilityHint(Text("task.reopen.accessibilityHint"))
                        }

                        if viewModel.canManageTask {
                            Button(role: .destructive) { viewModel.requestDelete() } label: {
                                Text("tasks.detail.delete_action")
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .background(.background, in: Capsule())
                            .disabled(!viewModel.canDeleteDirectly || viewModel.isDeleting)
                            .opacity(viewModel.canDeleteDirectly ? 1 : 0.4)
                            .accessibilityIdentifier(viewModel.canDeleteDirectly ? "tasks.detail.delete" : "tasks.detail.delete_disabled")
                            .accessibilityHint(viewModel.canDeleteDirectly ? Text("") : Text("tasks.delete.error_already_completed"))

                            if !viewModel.canDeleteDirectly {
                                Text("tasks.delete.error_already_completed")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    if viewModel.role == .member, task.status == .awaitingConfirmation {
                        Text("tasks.detail.admin_confirmation_hint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: geometry.size.width >= 1100 ? 694 : 540)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    private func detailsCard(for task: FamilyTask) -> some View {
        VStack(spacing: 0) {
            row(label: "tasks.form.weight_label", value: weightLabel(task.weight), identifier: "tasks.detail.weight")
            Divider().padding(.leading, 20)
            row(label: "tasks.form.scheduled_date_label", value: dateLabel(task.scheduledDate), identifier: "tasks.detail.date")
            Divider().padding(.leading, 20)
            row(label: "tasks.form.assignees_label", value: assigneeSummary(task), identifier: "tasks.detail.assignees")
            Divider().padding(.leading, 20)
            row(
                label: "routines.recurrence.title",
                value: viewModel.routine.map { frequencyLabel($0.frequency) }
                    ?? String(localized: "routines.recurrence.none"),
                identifier: "tasks.detail.recurrence"
            )
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 26))
    }

    private func bannerMessageKey(_ banner: TaskDetailBanner) -> LocalizedStringKey {
        switch banner {
        case .loadFailed: "tasks.detail.load_error"
        case .deleteFailed: "tasks.common.error_unavailable"
        case .deleteUncertain: "tasks.delete.error_uncertain"
        }
    }

    private var deleteBlockMessageKey: LocalizedStringKey {
        switch viewModel.deleteBlock {
        case .alreadyCompleted: "tasks.delete.error_already_completed"
        case .missionWouldHaveNoTasks: "tasks.delete.error_mission_would_be_empty"
        case .missionProtected, nil: "tasks.delete.error_mission_protected"
        }
    }

    private func completionFailureMessageKey(for failure: TaskCompletionFailure) -> LocalizedStringKey {
        failure == .needsRefresh
            ? "task.complete.error_unconfirmed"
            : "task.complete.still_pending"
    }

    private func row(label: LocalizedStringKey, value: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .layoutPriority(1)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .frame(minHeight: 51)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func statusBadge(for status: TaskStatus) -> some View {
        let (key, icon): (LocalizedStringKey, String) = switch status {
        case .pending: ("tasks.detail.status_pending", "circle")
        case .awaitingConfirmation: ("tasks.detail.status_awaiting_confirmation", "clock")
        case .completed: ("tasks.detail.status_completed", "checkmark.circle.fill")
        }
        return Label(key, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private func displayedStatus(for task: FamilyTask) -> TaskStatus {
        viewModel.role == .member && task.status == .awaitingConfirmation ? .pending : task.status
    }

    private func weightLabel(_ weight: EffortWeight) -> String {
        switch weight {
        case .low: String(localized: "tasks.detail.weight_low")
        case .medium: String(localized: "tasks.detail.weight_medium")
        case .high: String(localized: "tasks.detail.weight_high")
        }
    }

    private func dateLabel(_ wireDate: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: wireDate) else { return wireDate }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        let formatted = formatter.string(from: date)
        return formatted.prefix(1).uppercased(with: .current) + formatted.dropFirst()
    }

    private func frequencyLabel(_ frequency: RoutineFrequency) -> String {
        if frequency == .daily { return String(localized: "routines.recurrence.daily") }
        return String(format: String(localized: "routines.recurrence.every_days"), frequency.rawValue)
    }

    private func assigneeSummary(_ task: FamilyTask) -> String {
        guard !task.assigneeIDs.isEmpty else { return String(localized: "tasks.form.assignees_none") }
        let names = task.assigneeIDs.map { id in
            if id == currentMemberID { return String(localized: "tasks.detail.you") }
            return viewModel.memberNames[id] ?? String(localized: "tasks.detail.other_member")
        }
        let conjunction = String(localized: "tasks.detail.and")
        if names.count == 1 { return names[0] }
        if names.count == 2 { return names.joined(separator: " \(conjunction) ") }
        return names.dropLast().joined(separator: ", ") + " \(conjunction) " + names[names.count - 1]
    }
}
