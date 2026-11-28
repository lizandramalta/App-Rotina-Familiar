import SwiftUI

/// TEL-032 — current day or week of one member, separate from TEL-011's family list.
struct MemberDetailView: View {
    @State private var viewModel: MemberDetailViewModel
    @State private var showsRolePicker = false
    @State private var selectedRole: MemberRole?
    /// MOD-010 currently open; stays open on failure so the error is read in context (UX-003 §6).
    @State private var pendingChange: MemberChangeConfirmationView.Change?
    @State private var changeFailed = false
    /// SPEC-022 CA-16 / UX-022: Kids account deletion confirmation.
    @State private var showsKidsDeletionConfirmation = false
    @State private var showsKidsNameEditor = false
    @State private var draftKidsName = ""
    @State private var kidsNameIsInvalid = false
    @State private var kidsNameSaveFailed = false
    @State private var kidsNameRequiresRefresh = false
    @State private var kidsNameIsSaving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let onOpenTask: (UUID) -> Void
    let onRemoved: () -> Void
    let onUpdated: () -> Void

    init(viewModel: MemberDetailViewModel, onOpenTask: @escaping (UUID) -> Void,
         onRemoved: @escaping () -> Void = {}, onUpdated: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenTask = onOpenTask
        self.onRemoved = onRemoved
        self.onUpdated = onUpdated
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxxl) {
                navigationHeader
                if viewModel.detail != nil {
                    identification
                    VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                        notices
                        managementSections
                        tasksSection
                    }
                } else if viewModel.isLoading {
                    loadingSkeleton
                } else if let message = viewModel.errorMessage {
                    unavailableState(message)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.giant)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .hidesAppTabBar()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .inviteShareSheet(viewModel: viewModel, isPresented: viewModel.transientInvite != nil)
        .sheet(isPresented: $showsRolePicker, onDismiss: {
            // The selection closes the picker first; MOD-010 opens only afterwards (UX-003 §5.2).
            if let role = selectedRole { openConfirmation(.role(role)) }
            selectedRole = nil
        }) {
            rolePickerSheet
        }
        .sheet(item: $pendingChange, onDismiss: {
            if viewModel.isRemoved { finishRemoval() }
        }) { change in
            MemberChangeConfirmationView(
                change: change,
                memberName: viewModel.detail?.name ?? "",
                memberColor: memberColor,
                currentRole: viewModel.detail?.role ?? .member,
                isSubmitting: viewModel.isSaving,
                showsError: changeFailed,
                onConfirm: { Task { await confirm(change) } },
                onCancel: { pendingChange = nil }
            )
        }
        .sheet(isPresented: $showsKidsNameEditor) { NavigationStack { kidsNameEditor } }
        // Role change and removal use MOD-010; Kids account deletion keeps its SPEC-022 confirmation.
        .alert(
            Text(String(format: String(localized: "account.deletion.confirm.kids_title"), viewModel.targetName)),
            isPresented: $showsKidsDeletionConfirmation
        ) {
            Button("account.common.cancel", role: .cancel) {}
            Button("account.deletion.confirm.action", role: .destructive) {
                Task { await viewModel.deleteKidsAccount() }
            }
        } message: {
            Text("account.deletion.confirm.kids_message")
        }
        .onChange(of: viewModel.isRemoved) { _, removed in
            guard removed else { return }
            // With MOD-010 open, leave TEL-032 only once the sheet is gone.
            if pendingChange == nil { finishRemoval() } else { pendingChange = nil }
        }
    }

    // MARK: MOD-010

    private func openConfirmation(_ change: MemberChangeConfirmationView.Change) {
        changeFailed = false
        pendingChange = change
    }

    private func confirm(_ change: MemberChangeConfirmationView.Change) async {
        changeFailed = false
        switch change {
        case let .role(role):
            await viewModel.changeRole(role)
            // A lost response is reconciled by the reload: an already applied role closes the modal too.
            if !viewModel.managementFailed || viewModel.detail?.role == role {
                pendingChange = nil
            } else {
                changeFailed = true
            }
        case .remove:
            await viewModel.remove()
            if viewModel.isRemoved { return }
            // The member is gone or no longer visible: close and let TEL-032 show the confirmed state.
            if viewModel.detail == nil { pendingChange = nil } else { changeFailed = viewModel.managementFailed }
        }
    }

    private func finishRemoval() {
        onRemoved()
        dismiss()
    }

    private var memberColor: Color {
        guard let detail = viewModel.detail else { return Color.App.Member.you }
        return FamilyMemberPalette.colors(for: detail.id, isCurrentMember: viewModel.isCurrentMember).tint
    }

    // MARK: Header & identification

    private var navigationHeader: some View {
        HStack {
            Button { dismiss() } label: {
                FamilyCircleIconLabel(systemImage: "chevron.backward")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("family.tasks.back")
            .accessibilityIdentifier("family.member.detail.back")
            Spacer()
            if viewModel.canEditKidsName {
                Button("family.member.detail.edit") {
                    draftKidsName = viewModel.detail?.name ?? ""
                    kidsNameIsInvalid = false
                    kidsNameSaveFailed = false
                    kidsNameRequiresRefresh = false
                    showsKidsNameEditor = true
                }
                .font(.app(.subtitleStrong))
                .foregroundStyle(Color.App.Text.primary)
                .padding(.horizontal, AppSpacing.lg)
                .frame(minHeight: 44)
                .background(Color.App.Background.card, in: Capsule())
                .chalkStrokeBorder(Capsule(), color: Color.App.Border.card, lineWidth: 1.5)
                .contentShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("family.member.detail.edit_kids_name")
            }
        }
    }

    @ViewBuilder
    private var identification: some View {
        if let detail = viewModel.detail {
            VStack(spacing: AppSpacing.xs) {
                MemberAvatarView(name: detail.name, color: memberColor, size: 80)
                Text(detail.name)
                    .font(.app(.title2))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityIdentifier("family.member.detail.name")
                Text(detail.role.onboardingTitleKey)
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityIdentifier("family.member.detail.role")
                if detail.isFamilyCreator {
                    // Outline shield with a checkmark, like TEL-050's own badge (870:24419, Figma 879:13443).
                    Label("family.member.detail.creator_badge", systemImage: "checkmark.shield")
                        .font(.app(.noteStrong))
                        .foregroundStyle(Color.App.Text.highlight)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs + AppSpacing.xxs)
                        .background(Color.App.Background.cardHighlight, in: Capsule())
                        .padding(.top, AppSpacing.xs)
                        .accessibilityIdentifier("family.member.detail.creator_badge")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Notices (UX-004 TEL-034 outcomes, management/load failures)

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            retryNotice(message)
        }
        if viewModel.managementFailed && pendingChange == nil {
            retryNotice("family.member.manage.error")
        }
        if let message = viewModel.inviteErrorMessage {
            FamilyNoticeCard(message, tone: .error)
                .accessibilityIdentifier("memberInvite.error")
        }
        if viewModel.wasShareCancelled {
            FamilyNoticeCard("memberInvite.share.cancelled", tone: .warning)
                .accessibilityIdentifier("memberInvite.share.cancelled")
        }
    }

    private func retryNotice(_ message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            FamilyNoticeCard(message, tone: .error)
            Button("family.member.detail.retry") { Task { await viewModel.load() } }
                .font(.app(.subtitleStrong))
                .foregroundStyle(Color.App.Text.highlight)
                .frame(minHeight: 44)
                .padding(.leading, AppSpacing.lg)
                .disabled(viewModel.isLoading)
        }
        .accessibilityIdentifier("family.member.detail.error")
    }

    // MARK: Convite & Gestão

    @ViewBuilder
    private var managementSections: some View {
        if viewModel.canManage && viewModel.isCreator {
            FamilyNoticeCard("family.members.creator_protected")
                .accessibilityIdentifier("family.members.creator_protected")
        } else if viewModel.canManage {
            if viewModel.canIssueInvite {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    FamilySectionLabel("family.member.detail.invite_section")
                    Button {
                        Task { await viewModel.issueInvite() }
                    } label: {
                        // UX-004 UX-06/UX-07: one label and a direct issuance whether or not a previous invite exists.
                        managementRow(
                            "family.member.manage.generate_invite",
                            symbol: "square.and.arrow.up", chevron: true, isBusy: viewModel.isIssuingInvite
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isIssuingInvite)
                    .appCard(cornerRadius: AppRadius.pill)
                    .accessibilityIdentifier("memberInvite.issue.title")
                }
            }
            if viewModel.canManageTarget {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    FamilySectionLabel("family.member.detail.management_section")
                    VStack(spacing: 0) {
                        Button { showsRolePicker = true } label: {
                            // Figma 870:24275: a bare person glyph, not person.crop.circle.
                            managementRow("family.member.manage.role", symbol: "person", chevron: true)
                        }
                        .accessibilityIdentifier("family.member.detail.change_role")
                        FamilyCardSeparator(leadingInset: AppSpacing.lg + 24 + AppSpacing.base)
                        Button { openConfirmation(.remove) } label: {
                            managementRow("family.member.manage.remove", symbol: "trash", chevron: false, destructive: true)
                        }
                        .accessibilityIdentifier("family.member.detail.remove")
                        .accessibilityHint("family.member.manage.remove_hint")
                        if viewModel.canDeleteKidsAccount {
                            FamilyCardSeparator(leadingInset: AppSpacing.lg + 24 + AppSpacing.base)
                            Button { showsKidsDeletionConfirmation = true } label: {
                                managementRow(
                                    "family.members.delete_account", symbol: "person.crop.circle.badge.xmark",
                                    chevron: false, destructive: true
                                )
                            }
                            .accessibilityIdentifier("family.member.detail.delete_account")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaving)
                    .appCard(cornerRadius: AppRadius.pill)
                }
            }
        }
    }

    private func managementRow(
        _ title: LocalizedStringKey, symbol: String, chevron: Bool, destructive: Bool = false, isBusy: Bool = false
    ) -> some View {
        HStack(spacing: AppSpacing.base) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                // "Remover membro" is #423C1F, never red (Figma 870:24320); the label and MOD-010 carry the meaning.
                .foregroundStyle(destructive ? Color.App.Text.primary : Color.App.Action.primary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.app(destructive ? .bodyStrong : .body))
                .foregroundStyle(Color.App.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isBusy {
                ProgressView().tint(Color.App.Action.primary)
            } else if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var rolePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if let currentRole = viewModel.detail?.role {
                        HStack {
                            Text("family.members.role.label")
                                .font(.app(.body))
                                .foregroundStyle(Color.App.Text.primary)
                            Spacer()
                            Text(currentRole.onboardingTitleKey)
                                .font(.app(.subtitleStrong))
                                .foregroundStyle(Color.App.Text.secondary)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .frame(minHeight: 52)
                        .appCard(cornerRadius: AppRadius.pill)
                        .accessibilityElement(children: .combine)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.allowedRoles.enumerated()), id: \.element) { index, role in
                            if index > 0 { FamilyCardSeparator() }
                            Button {
                                selectedRole = role
                                showsRolePicker = false
                            } label: {
                                HStack {
                                    Text(role.onboardingTitleKey)
                                        .font(.app(.body))
                                        .foregroundStyle(Color.App.Text.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.App.Text.secondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("family.member.role.option.\(role.rawValue)")
                        }
                    }
                    .appCard(cornerRadius: AppRadius.pill)
                }
                .padding(AppSpacing.xxl)
            }
            .background(Color.App.Background.app.ignoresSafeArea())
            .navigationTitle("family.member.manage.role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("family.settings.hub.cancel") { showsRolePicker = false }
                        .tint(Color.App.Action.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var kidsNameEditor: some View {
        FamilyKidsNameEditor(
            name: $draftKidsName,
            fieldIdentifier: "family.member.detail.kids_name",
            isInvalid: kidsNameIsInvalid,
            showsError: kidsNameSaveFailed,
            requiresRefresh: kidsNameRequiresRefresh,
            isSaving: kidsNameIsSaving,
            hasChanges: draftKidsName != viewModel.detail?.name,
            onRetry: {
                Task {
                    if let current = await viewModel.reconcileKidsName() {
                        kidsNameRequiresRefresh = false
                        if current.name == draftKidsName && current.role == .kid {
                            showsKidsNameEditor = false
                            onUpdated()
                        } else {
                            kidsNameSaveFailed = current.role != .kid
                        }
                    }
                }
            },
            onSave: saveKidsName,
            onClose: { showsKidsNameEditor = false }
        )
        .onChange(of: draftKidsName) { _, _ in kidsNameIsInvalid = false }
    }

    private func saveKidsName() {
        guard case .success = FamilyCreationValidation.validatedName(draftKidsName) else {
            kidsNameIsInvalid = true
            return
        }
        kidsNameIsSaving = true
        kidsNameSaveFailed = false
        Task {
            let result = await viewModel.updateKidsName(
                draftKidsName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            kidsNameIsSaving = false
            switch result {
            case .saved:
                showsKidsNameEditor = false
                onUpdated()
            case .failed, .noLongerEligible:
                kidsNameSaveFailed = true
            case .reconciliationRequired:
                kidsNameRequiresRefresh = true
            }
        }
    }

    // MARK: States

    private var loadingSkeleton: some View {
        VStack(spacing: AppSpacing.xxl) {
            VStack(spacing: AppSpacing.sm) {
                Circle().fill(Color.App.Background.subtle).frame(width: 80, height: 80)
                Capsule().fill(Color.App.Background.subtle).frame(width: 160, height: 18)
                Capsule().fill(Color.App.Background.subtle).frame(width: 90, height: 12)
            }
            // Figma 870:24516: a single placeholder card — the confirmed content may be only
            // tasks (member consult) or also invite/management rows (admin view), so the
            // skeleton must not hint at a fixed number of sections (no anticipated actions).
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .fill(Color.App.Background.subtle)
                .frame(height: 156)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.overview.loading")
        .accessibilityIdentifier("family.member.detail.loading")
    }

    /// 403/404 clear the detail: no stale data is shown (UX-003 §6).
    /// A removed/not-found member (870:24540) is permanent — no retry can bring it back — while a
    /// transient network failure keeps its retry affordance.
    private func unavailableState(_ message: LocalizedStringKey) -> some View {
        let isPermanentlyGone = viewModel.failure == .notFound
        return VStack(spacing: AppSpacing.lg) {
            // Figma shows a bare person glyph, not person.crop.circle.badge.exclamationmark.
            Image(systemName: "person")
                .font(.system(size: 48))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityHidden(true)
            if isPermanentlyGone {
                Text("family.member.detail.unavailable_title")
                    .font(.app(.title2))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.center)
            }
            Text(message)
                .font(.app(.body))
                .foregroundStyle(isPermanentlyGone ? Color.App.Text.secondary : Color.App.Text.primary)
                .multilineTextAlignment(.center)
            if !isPermanentlyGone {
                Button("family.member.detail.retry") { Task { await viewModel.load() } }
                    .buttonStyle(AppPillButtonStyle(kind: .secondary))
                    .disabled(viewModel.isLoading)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .accessibilityIdentifier("family.member.detail.error")
    }

    // MARK: Tasks (UX-009 TEL-032)

    private var periodSummary: String {
        let progress = viewModel.taskViewModel.progress
        let completed = progress?.completed ?? 0
        let total = progress?.total ?? 0
        let range = viewModel.taskViewModel.range
        if viewModel.period == .week {
            let title = FamilyOverviewDates.rangeTitle(range, timeZoneID: viewModel.taskViewModel.timeZoneID)
            return String(format: String(localized: "family.member.detail.week_summary"), title, completed, total)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: viewModel.taskViewModel.timeZoneID) ?? .current
        formatter.dateFormat = "EEE, d 'de' MMM"
        let wire = DateFormatter()
        wire.locale = Locale(identifier: "en_US_POSIX")
        wire.timeZone = formatter.timeZone
        wire.dateFormat = "yyyy-MM-dd"
        let date = wire.date(from: range.startDate) ?? .now
        return String(format: String(localized: "family.member.detail.day_summary"),
                      formatter.string(from: date), completed, total)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Picker("family.member.detail.period", selection: Binding(
                get: { viewModel.period },
                set: { period in Task { await viewModel.selectPeriod(period) } }
            )) {
                Text("family.member.detail.day").tag(MemberDetailViewModel.Period.day)
                Text("family.member.detail.week").tag(MemberDetailViewModel.Period.week)
            }
            .pickerStyle(.segmented)
            .background(SegmentedControlStyler(identifier: "family.member.detail.period"))
            .accessibilityIdentifier("family.member.detail.period")

            FamilySectionLabel(verbatim: periodSummary)
                .padding(.top, AppSpacing.xs)
            if viewModel.taskViewModel.failed {
                retryNotice("family.tasks.error")
            } else if viewModel.taskViewModel.isLoading && viewModel.taskViewModel.items.isEmpty {
                RoundedRectangle(cornerRadius: AppRadius.pill)
                    .fill(Color.App.Background.subtle)
                    .frame(height: 108)
                    .accessibilityLabel("family.overview.loading")
            } else if viewModel.taskViewModel.items.isEmpty {
                Text("family.tasks.empty")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .appCard(cornerRadius: AppRadius.pill)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.taskViewModel.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { FamilyCardSeparator(leadingInset: AppSpacing.lg + 24 + AppSpacing.md) }
                        Button {
                            onOpenTask(item.id)
                        } label: {
                            taskRow(item)
                        }
                        .buttonStyle(.plain)
                        .task { await viewModel.taskViewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .appCard(cornerRadius: AppRadius.pill)
            }
            if viewModel.taskViewModel.isLoadingMore {
                ProgressView().tint(Color.App.Action.primary).frame(maxWidth: .infinity, minHeight: 44)
            }
            if viewModel.taskViewModel.loadMoreFailed {
                Button("family.member.detail.retry") { Task { await viewModel.taskViewModel.loadMore() } }
                    .font(.app(.subtitleStrong))
                    .foregroundStyle(Color.App.Text.highlight)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func taskRow(_ item: FamilyTaskItem) -> some View {
        let isCompleted = item.displayStatus == .completed
        return HStack(spacing: AppSpacing.md) {
            FamilyTaskStatusIcon(status: item.displayStatus)
            Text(item.task.title)
                .font(.app(.body))
                .strikethrough(isCompleted, color: Color.App.Text.secondary)
                .foregroundStyle(isCompleted ? Color.App.Text.secondary : Color.App.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityHidden(true)
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.base)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.task.title), \(statusSubtitle(item))")
        .accessibilityHint("tasks.personal.openDetailHint")
        .accessibilityIdentifier("family.member.detail.task.\(item.id.uuidString)")
    }

    private func statusTitle(_ status: TaskStatus) -> LocalizedStringResource {
        switch status {
        case .pending: "family.member.detail.status.pending"
        case .awaitingConfirmation: "family.member.detail.status.awaiting"
        case .completed: "family.member.detail.status.completed"
        }
    }

    private func statusSubtitle(_ item: FamilyTaskItem) -> String {
        if item.displayStatus == .completed, let completedAt = item.completedAt {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = TimeZone(identifier: viewModel.taskViewModel.timeZoneID) ?? .current
            formatter.timeStyle = .short
            return String(format: String(localized: "family.member.detail.completed_at"),
                          formatter.string(from: completedAt))
        }
        return String(localized: statusTitle(item.displayStatus))
    }

}
