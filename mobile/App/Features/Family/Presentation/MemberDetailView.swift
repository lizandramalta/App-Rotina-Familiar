import SwiftUI

/// TEL-032 — current day or week of one member, separate from TEL-011's family list.
struct MemberDetailView: View {
    @State private var viewModel: MemberDetailViewModel
    @State private var showsRolePicker = false
    @State private var selectedRole: MemberRole?
    @State private var pendingRole: MemberRole?
    @State private var showsRemovalConfirmation = false
    @State private var showsReissueConfirmation = false
    @State private var showsKidsNameEditor = false
    @State private var draftKidsName = ""
    @State private var kidsNameIsInvalid = false
    @State private var kidsNameSaveFailed = false
    @State private var kidsNameRequiresRefresh = false
    @State private var kidsNameIsSaving = false
    @State private var showsKidsNameDiscard = false
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
            VStack(alignment: .leading, spacing: 24) {
                navigationHeader
                identification
                VStack(alignment: .leading, spacing: 22) {
                    if viewModel.detail != nil {
                        managementSections
                        tasksSection
                    } else if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .accessibilityIdentifier("family.member.detail.loading")
                    }
                    if let message = viewModel.errorMessage { failureCard(message) }
                    if viewModel.managementFailed { failureCard("family.member.manage.error") }
                    if let message = viewModel.inviteErrorMessage {
                        failureCard(message).accessibilityIdentifier("memberInvite.error")
                    }
                    if viewModel.wasShareCancelled {
                        Text("memberInvite.share.cancelled")
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("memberInvite.share.cancelled")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .navigationDestination(isPresented: $showsReissueConfirmation) {
            MemberInviteConfirmationView(viewModel: viewModel)
        }
        .inviteShareSheet(
            viewModel: viewModel,
            isPresented: viewModel.transientInvite != nil && !showsReissueConfirmation
        )
        .sheet(isPresented: $showsRolePicker, onDismiss: {
            pendingRole = selectedRole
            selectedRole = nil
        }) {
            rolePickerSheet
        }
        .sheet(isPresented: $showsKidsNameEditor) { NavigationStack { kidsNameEditor } }
        .alert("family.member.manage.role_confirm", isPresented: Binding(
            get: { pendingRole != nil },
            set: { if !$0 { pendingRole = nil } }
        )) {
            Button("family.settings.hub.cancel", role: .cancel) { pendingRole = nil }
            Button("family.member.manage.role_confirm_action") {
                if let role = pendingRole { Task { await viewModel.changeRole(role) } }
                pendingRole = nil
            }
        } message: {
            Text("family.member.manage.role_confirm_message")
        }
        .alert("family.member.manage.remove", isPresented: $showsRemovalConfirmation) {
            Button("family.settings.hub.cancel", role: .cancel) {}
            Button("family.member.manage.remove", role: .destructive) {
                Task { await viewModel.remove() }
            }
        } message: {
            Text("family.member.manage.remove_message")
        }
        .onChange(of: viewModel.isRemoved) { _, removed in
            if removed { onRemoved(); dismiss() }
        }
    }

    private var navigationHeader: some View {
        HStack {
            circleButton("chevron.left", label: "family.tasks.back") { dismiss() }
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
                .font(.system(size: 17))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(.white, in: Capsule())
                .accessibilityIdentifier("family.member.detail.edit_kids_name")
            }
        }
    }

    private var identification: some View {
        VStack(spacing: 5) {
            if let detail = viewModel.detail {
                Text(String(detail.name.prefix(1)).uppercased(with: locale))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .frame(width: 80, height: 80)
                    .background(Color(uiColor: .systemGray5), in: Circle())
                    .accessibilityHidden(true)
                Text(detail.name)
                    .font(.system(size: 22, weight: .bold))
                    .accessibilityIdentifier("family.member.detail.name")
                    .padding(.top, 10)
                Text(detail.role.onboardingTitleKey)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("family.member.detail.role")
                if detail.isFamilyCreator {
                    Label("family.member.detail.creator_badge", systemImage: "shield.lefthalf.filled")
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .systemGray5), in: Capsule())
                        .accessibilityIdentifier("family.member.detail.creator_badge")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func circleButton(
        _ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 20, height: 20)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
        .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var managementSections: some View {
        if viewModel.canManage && viewModel.isCreator {
            Label("family.members.creator_protected", systemImage: "info.circle.fill")
                .font(.subheadline)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
        } else if viewModel.canManage {
            if viewModel.canIssueInvite {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("family.member.detail.invite_section")
                    Button {
                        if viewModel.hasPreviousInvite { showsReissueConfirmation = true }
                        else { Task { await viewModel.issueFirstInvite() } }
                    } label: {
                        managementRow(
                            viewModel.hasPreviousInvite
                                ? "family.member.manage.generate_new_invite"
                                : "family.member.manage.generate_invite",
                            symbol: "square.and.arrow.up", chevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isIssuingInvite)
                    .accessibilityIdentifier(viewModel.hasPreviousInvite
                        ? "memberInvite.reissue.title" : "memberInvite.issue.title")
                }
            }
            if viewModel.canManageTarget {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("family.member.detail.management_section")
                    VStack(spacing: 0) {
                        Button { showsRolePicker = true } label: {
                            managementRow("family.member.manage.role", symbol: "person.crop.circle", chevron: true)
                        }
                        .accessibilityIdentifier("family.member.detail.change_role")
                        Divider().padding(.leading, 48)
                        Button { showsRemovalConfirmation = true } label: {
                            managementRow("family.member.manage.remove", symbol: "trash", chevron: false, emphasized: true)
                        }
                        .accessibilityIdentifier("family.member.detail.remove")
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaving)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
            }
        }
    }

    private func sectionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.system(size: 13)).foregroundStyle(.secondary).padding(.leading, 20)
    }

    private func managementRow(
        _ title: LocalizedStringKey, symbol: String, chevron: Bool, emphasized: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 19)).frame(width: 20).accessibilityHidden(true)
            Text(title)
                .font(.system(size: 16, weight: emphasized ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
            if chevron {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var rolePickerSheet: some View {
        NavigationStack {
            List {
                if let currentRole = viewModel.detail?.role {
                    HStack {
                        Text("family.members.role.label")
                        Spacer()
                        Text(currentRole.onboardingTitleKey)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(viewModel.allowedRoles, id: \.self) { role in
                    Button {
                        selectedRole = role
                        showsRolePicker = false
                    } label: {
                        HStack {
                            Text(role.onboardingTitleKey)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("family.member.role.option.\(role.rawValue)")
                }
            }
            .navigationTitle("family.member.manage.role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("family.settings.hub.cancel") { showsRolePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var kidsNameEditor: some View {
        Form {
            TextField("family.member.manage.name", text: $draftKidsName)
                .onChange(of: draftKidsName) { _, _ in kidsNameIsInvalid = false }
                .accessibilityIdentifier("family.member.detail.kids_name")
            if kidsNameIsInvalid {
                Text("family.members.name.error_invalid").foregroundStyle(.red)
            }
            if kidsNameSaveFailed || kidsNameRequiresRefresh {
                Text("family.member.manage.error").foregroundStyle(.red)
            }
            if kidsNameRequiresRefresh {
                Button("family.member.detail.retry") {
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
                }
            }
        }
        .navigationTitle("family.settings.hub.edit_kids_name")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("family.settings.hub.cancel") {
                    if draftKidsName != viewModel.detail?.name { showsKidsNameDiscard = true }
                    else { showsKidsNameEditor = false }
                }
                .disabled(kidsNameIsSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("family.settings.hub.save") {
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
                .disabled(kidsNameIsSaving || kidsNameRequiresRefresh || draftKidsName == viewModel.detail?.name)
            }
        }
        .confirmationDialog("family.members.discard.title", isPresented: $showsKidsNameDiscard) {
            Button("family.members.discard.confirm", role: .destructive) { showsKidsNameEditor = false }
            Button("family.members.discard.keep_editing", role: .cancel) {}
        } message: {
            Text("family.members.discard.message")
        }
        .interactiveDismissDisabled(kidsNameIsSaving || draftKidsName != viewModel.detail?.name)
    }

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
        VStack(alignment: .leading, spacing: 10) {
            Picker("family.member.detail.period", selection: Binding(
                get: { viewModel.period },
                set: { period in Task { await viewModel.selectPeriod(period) } }
            )) {
                Text("family.member.detail.day").tag(MemberDetailViewModel.Period.day)
                Text("family.member.detail.week").tag(MemberDetailViewModel.Period.week)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("family.member.detail.period")

            Text(periodSummary)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
                .accessibilityAddTraits(.isHeader)
            if viewModel.taskViewModel.failed {
                failureCard("family.tasks.error")
            } else if viewModel.taskViewModel.isLoading && viewModel.taskViewModel.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 80)
            } else if viewModel.taskViewModel.items.isEmpty {
                Text("family.tasks.empty")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.taskViewModel.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 54) }
                        Button {
                            onOpenTask(item.id)
                        } label: {
                            taskRow(item)
                        }
                        .buttonStyle(.plain)
                        .task { await viewModel.taskViewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 22))
            }
            if viewModel.taskViewModel.isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
            if viewModel.taskViewModel.loadMoreFailed {
                Button("family.member.detail.retry") { Task { await viewModel.taskViewModel.loadMore() } }
            }
        }
    }

    private func taskRow(_ item: FamilyTaskItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbol(item.displayStatus))
                .font(.system(size: 20))
                .frame(width: 22, height: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.task.title)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(item.displayStatus == .completed)
                    .foregroundStyle(item.displayStatus == .completed ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14).accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.task.title), \(statusSubtitle(item))")
        .accessibilityHint("tasks.personal.openDetailHint")
        .accessibilityIdentifier("family.member.detail.task.\(item.id.uuidString)")
    }

    private func statusSymbol(_ status: TaskStatus) -> String {
        switch status {
        case .pending: "circle"
        case .awaitingConfirmation: "clock"
        case .completed: "checkmark.circle.fill"
        }
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

    private func failureCard(_ message: LocalizedStringKey) -> some View {
        VStack(spacing: 8) {
            Text(message).font(.footnote).foregroundStyle(.red)
            Button("family.member.detail.retry") { Task { await viewModel.load() } }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("family.member.detail.error")
    }

}
