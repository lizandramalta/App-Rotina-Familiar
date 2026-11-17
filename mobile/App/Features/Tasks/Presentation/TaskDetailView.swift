import SwiftUI

/// TEL-012 — Editar/Excluir (Admin/Membro only) and Reabrir (Admin/Membro always, Kids on
/// their own task — SPEC-011). On a routine occurrence, Editar and Excluir first ask the scope in
/// MOD-003 (SPEC-008 Fase 2, UX-008 §5.4).
struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    @State private var showsSignalSheet = false
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
            } else if let task = viewModel.task {
                content(for: task)
            } else {
                // Keeps the Group's branch always non-empty before `load()` sets `isLoading`.
                Color.clear
            }
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .hidesAppTabBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.task != nil, viewModel.canManageTask {
                    Button("Editar") {
                        if viewModel.requestEdit() { onRequestEdit(nil) }
                    }
                    .tint(Color.App.Action.primary)
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
        .sheet(isPresented: $showsSignalSheet) {
            KidsSignalSheet(viewModel: viewModel)
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
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(task.title)
                            .font(.app(.title1))
                            .foregroundStyle(Color.App.Text.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statusBadge(for: displayedStatus(for: task))
                            .accessibilityFocused($isStatusFocused)
                            .accessibilityIdentifier("tasks.detail.status")
                    }
                    .padding(.horizontal, AppSpacing.xs)

                    if viewModel.showReopenSuccessBanner {
                        Label("task.reopen.success_banner", systemImage: "checkmark.circle.fill")
                            .font(.app(.subtitle))
                            .foregroundStyle(Color.App.Text.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.lg)
                            .appCard()
                    }

                    detailsCard(for: task)

                    if viewModel.role != .kid,
                       task.routineID != nil,
                       viewModel.routine?.materializationState == .pending || viewModel.routineLoadFailed {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            if viewModel.routine?.materializationState == .pending {
                                Label("routines.materialization.preparing", systemImage: "clock")
                                    .accessibilityIdentifier("routines.detail.preparing")
                            }
                            if viewModel.routineLoadFailed {
                                Label("routines.error_unavailable", systemImage: "exclamationmark.triangle")
                                Button("tasks.error.retry") { Task { await viewModel.refreshRoutine() } }
                                    .font(.app(.subtitleStrong))
                                    .foregroundStyle(Color.App.Text.highlight)
                            }
                        }
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                        .appCard()
                    }

                    if let note = task.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("tasks.detail.note_label")
                                .font(.app(.caption))
                                .foregroundStyle(Color.App.Text.secondary)
                                .padding(.leading, AppSpacing.xxl)
                            Text(note)
                                .font(.app(.body))
                                .foregroundStyle(Color.App.Text.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.xxl)
                                .padding(.vertical, AppSpacing.base)
                                .appCard()
                        }
                    }

                    if let banner = viewModel.banner {
                        Text(bannerMessageKey(banner))
                            .font(.app(.subtitle))
                            .foregroundStyle(Color.App.System.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.reopenFailed {
                        notice {
                            Text("tasks.common.error_unavailable")
                                .foregroundStyle(Color.App.System.destructive)
                            noticeButton("Tentar novamente") { Task { await viewModel.requestReopen() } }
                        }
                    }

                    if viewModel.memberDirectoryLoadFailed {
                        notice {
                            Text("tasks.detail.assignees_unavailable")
                                .foregroundStyle(Color.App.Text.secondary)
                            noticeButton("tasks.error.retry") { Task { await viewModel.retryMemberRoles() } }
                        }
                    }

                    if let failure = viewModel.completionFailure {
                        notice {
                            Text(completionFailureMessageKey(for: failure))
                                .foregroundStyle(Color.App.Text.secondary)
                            if failure == .needsRefresh {
                                noticeButton("task.complete.refresh_status") {
                                    Task { await viewModel.refreshCompletionStatus() }
                                }
                                .disabled(viewModel.isCompleting)
                                .accessibilityIdentifier("tasks.detail.complete.refresh")
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }

                    VStack(spacing: AppSpacing.md) {
                        if viewModel.showsCompleteAction {
                            Button {
                                Task { await viewModel.requestComplete() }
                            } label: {
                                Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button")
                            }
                            .buttonStyle(AppPillButtonStyle(kind: .primary))
                            .disabled(!viewModel.canComplete)
                            .accessibilityIdentifier("tasks.detail.complete")
                            .accessibilityLabel(Text(viewModel.isCompleting ? "task.complete.pending" : "task.complete.button"))
                        }

                        if viewModel.canReopen {
                            Button {
                                Task { await viewModel.requestReopen() }
                            } label: {
                                Text(viewModel.isReopening ? "task.reopen.pending" : "task.reopen.button")
                            }
                            // Kids get the larger 56 pt touch target (TEL-041); adults keep 50 pt.
                            .buttonStyle(AppPillButtonStyle(
                                kind: .secondary,
                                height: viewModel.role == .kid ? AppPillButtonStyle.kidsHeight : AppPillButtonStyle.height
                            ))
                            .disabled(viewModel.isReopening)
                            .accessibilityIdentifier("tasks.detail.reopen")
                            .accessibilityLabel(Text("task.reopen.accessibilityLabel"))
                            .accessibilityHint(Text("task.reopen.accessibilityHint"))
                        }

                        if viewModel.canManageTask {
                            Button(role: .destructive) { viewModel.requestDelete() } label: {
                                Text("tasks.detail.delete_action")
                                    .font(.app(.body))
                                    .frame(maxWidth: .infinity, minHeight: Self.actionHeight)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.App.System.destructive)
                            .appCard(cornerRadius: Self.actionHeight / 2)
                            .disabled(!viewModel.canDeleteDirectly || viewModel.isDeleting)
                            .opacity(viewModel.canDeleteDirectly ? 1 : 0.4)
                            .accessibilityIdentifier(viewModel.canDeleteDirectly ? "tasks.detail.delete" : "tasks.detail.delete_disabled")
                            .accessibilityHint(viewModel.canDeleteDirectly ? Text("") : Text("tasks.delete.error_already_completed"))

                            if !viewModel.canDeleteDirectly {
                                Text("tasks.delete.error_already_completed")
                                    .font(.app(.caption))
                                    .foregroundStyle(Color.App.Text.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, AppSpacing.xxl)
                            }
                        }
                    }

                    if viewModel.role == .member, task.status == .awaitingConfirmation {
                        Text("tasks.detail.admin_confirmation_hint")
                            .font(.app(.caption))
                            .foregroundStyle(Color.App.Text.secondary)
                            .padding(.horizontal, AppSpacing.xxl)
                    }
                }
                .frame(maxWidth: geometry.size.width >= Self.wideLayoutBreakpoint ? Self.wideContentWidth : Self.contentWidth)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity)
            }
            .background(Color.App.Background.app)
            // TEL-041: the Kids signal CTA stays pinned at the bottom of the screen.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.canSignal {
                    Button { showsSignalSheet = true } label: {
                        Label("kids.signal.open", systemImage: "hand.raised.fill")
                    }
                        .buttonStyle(AppPillButtonStyle(kind: .primary, height: AppPillButtonStyle.kidsHeight))
                        .accessibilityIdentifier("kids.signal.open")
                        .frame(maxWidth: Self.contentWidth)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(Color.App.Background.app.ignoresSafeArea())
                }
            }
        }
    }

    private static let actionHeight: CGFloat = 50
    private static let wideLayoutBreakpoint: CGFloat = 1100
    private static let wideContentWidth: CGFloat = 694
    private static let contentWidth: CGFloat = 540
    private static let rowMinHeight: CGFloat = 51

    /// Network/error notice card (message + inline retry action).
    private func notice<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .font(.app(.subtitle))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .appCard()
    }

    private func noticeButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Text.highlight)
    }

    private func detailsCard(for task: FamilyTask) -> some View {
        VStack(spacing: 0) {
            row(label: "tasks.form.weight_label", value: weightLabel(task.weight), identifier: "tasks.detail.weight")
            separator
            row(label: "tasks.form.scheduled_date_label", value: dateLabel(task.scheduledDate), identifier: "tasks.detail.date")
            separator
            row(label: "tasks.form.assignees_label", value: assigneeSummary(task), identifier: "tasks.detail.assignees")
            separator
            row(
                label: "routines.recurrence.title",
                value: viewModel.routine.map { frequencyLabel($0.frequency) }
                    ?? String(localized: "routines.recurrence.none"),
                identifier: "tasks.detail.recurrence"
            )
        }
        .appCard()
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.App.Border.separator)
            .frame(height: 1)
            .padding(.leading, AppSpacing.xxl)
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
                .foregroundStyle(Color.App.Text.primary)
                .layoutPriority(1)
            Text(value)
                .foregroundStyle(Color.App.Text.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.app(.body))
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.base)
        .frame(minHeight: Self.rowMinHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private static let badgeIconSize: CGFloat = 14

    private func statusBadge(for status: TaskStatus) -> some View {
        let (key, icon): (LocalizedStringKey, Image) = switch status {
        case .pending: ("tasks.detail.status_pending", Image(systemName: "circle"))
        // Figma 907:27388 dashed clock, tinted as a template.
        case .awaitingConfirmation: (
            "tasks.detail.status_awaiting_confirmation",
            Image("TaskStatusAwaiting").renderingMode(.template)
        )
        case .completed: ("tasks.detail.status_completed", Image(systemName: "checkmark.circle.fill"))
        }
        return Label {
            Text(key)
        } icon: {
            if status == .awaitingConfirmation {
                icon.resizable().scaledToFit().frame(width: Self.badgeIconSize, height: Self.badgeIconSize)
            } else {
                icon
            }
        }
        .font(.app(.caption))
        .foregroundStyle(Color.App.Text.primary)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.App.Background.cardHighlight, in: Capsule())
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
