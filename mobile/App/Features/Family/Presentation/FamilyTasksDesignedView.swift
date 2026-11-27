import SwiftUI
import UIKit

/// Approved TEL-011 composition; TEL-032 has its own compact daily list.
struct FamilyTasksDesignedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State var viewModel: FamilyTasksViewModel
    let onOpenTask: (UUID) -> Void
    @State private var showsFilter = false
    @State private var showsReportMenu = false
    @State private var showsWeekSelector = false
    @State private var isGeneratingReport = false
    @State private var reportFailed = false
    @State private var reportFile: ReportFile?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.base) {
                header
                Text("family.tasks.title")
                    .font(.app(.title1))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                memberFilters
                periodSummary

                if viewModel.isLoading && viewModel.items.isEmpty {
                    loadingSkeleton
                }
                if viewModel.failed {
                    if viewModel.items.isEmpty { failureCard } else { refreshFailureBanner }
                }
                if !viewModel.isLoading && viewModel.items.isEmpty && !viewModel.failed {
                    emptyState
                }

                taskSection(.pending)
                if viewModel.role == .administrator { taskSection(.awaitingConfirmation) }
                taskSection(.completed)

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Color.App.Action.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                if viewModel.loadMoreFailed {
                    Button("family.member.detail.retry") { Task { await viewModel.loadMore() } }
                        .font(.app(.subtitleStrong))
                        .foregroundStyle(Color.App.Text.highlight)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.giant)
            // Readable column on iPad: chips and rows do not stretch across the whole canvas.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .hidesAppTabBar()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showsFilter) {
            if let firstDate = viewModel.familyCreatedAt {
                FamilyTasksFilterSheet(
                    range: viewModel.range,
                    status: viewModel.status,
                    statuses: viewModel.availableStatuses,
                    firstDate: firstDate,
                    timeZoneID: viewModel.timeZoneID,
                    countProvider: { range, status in
                        try await viewModel.previewCount(range: range, status: status)
                    },
                    onApply: { range, status in
                        Task { await viewModel.applyFilters(range: range, status: status) }
                    }
                )
            }
        }
        .navigationDestination(isPresented: $showsWeekSelector) {
            if let report = viewModel.makeReportView() {
                report
                    .hidesAppTabBar()
            }
        }
        .sheet(item: $reportFile) { FamilyReportShareSheet(url: $0.url) }
        .alert("family.report.failure_title", isPresented: $reportFailed) {
            Button("family.report.cancel", role: .cancel) {}
            Button("family.report.retry") { Task { await generateReport() } }
        } message: {
            Text("family.report.failure_message")
        }
        // UX-019: VoiceOver announces the generating state as soon as it starts.
        .onChange(of: isGeneratingReport) { _, isGenerating in
            guard isGenerating else { return }
            AccessibilityNotification.Announcement(String(localized: "family.report.generating")).post()
        }
        .overlay(alignment: .bottom) {
            if isGeneratingReport {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView().tint(Color.App.Text.onAction)
                    Text("family.report.generating")
                        .font(.app(.subtitleStrong))
                }
                .foregroundStyle(Color.App.Text.onAction)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(Color.App.Text.primary, in: Capsule())
                .shadow(color: Color.App.Text.primary.opacity(0.2), radius: 8, y: 4)
                .padding(.bottom, AppSpacing.xl)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("family.report.generating")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Button { dismiss() } label: {
                FamilyCircleIconLabel(systemImage: "chevron.backward")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("family.tasks.back")
            Spacer()
            Button { showsFilter = true } label: {
                FamilyCircleIconLabel(systemImage: "line.3.horizontal.decrease", isActive: isFilterActive)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.familyCreatedAt == nil)
            .accessibilityLabel("family.period.filter_title")
            .accessibilityIdentifier("family.tasks.range")
            Button { showsReportMenu = true } label: {
                if isGeneratingReport {
                    ProgressView()
                        .tint(Color.App.Action.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.App.Background.card, in: Circle())
                } else {
                    FamilyCircleIconLabel(systemImage: "ellipsis")
                }
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingReport || viewModel.makeReportView() == nil)
            .accessibilityLabel("family.tasks.more")
            .accessibilityIdentifier("family.tasks.more")
            .popover(isPresented: $showsReportMenu, arrowEdge: .top) {
                Button {
                    showsReportMenu = false
                    if viewModel.reportSpansMultipleWeeks {
                        showsWeekSelector = true
                    } else {
                        Task { await generateReport() }
                    }
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("family.tasks.generate_pdf")
                                .font(.app(.subtitleStrong))
                                .foregroundStyle(Color.App.Text.primary)
                            Text(reportWeekLabel)
                                .font(.app(.caption))
                                .foregroundStyle(Color.App.Text.secondary)
                        }
                        Spacer(minLength: AppSpacing.md)
                        // Figma 870:23703: the system share glyph, trailing — not a leading doc icon.
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.App.Text.primary)
                            .accessibilityHidden(true)
                    }
                    .frame(minWidth: 220, minHeight: 44, alignment: .leading)
                    .padding(AppSpacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .presentationBackground(Color.App.Background.card)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    /// Filled filter button whenever the sheet holds something other than "current week + Todos".
    private var isFilterActive: Bool {
        guard let firstDate = viewModel.familyCreatedAt else { return false }
        return viewModel.status != .all
            || FamilyRangeFilterSheet.isCustomRange(viewModel.range, familyCreatedAt: firstDate, timeZoneID: viewModel.timeZoneID)
    }

    // MARK: Member chips

    private var memberFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: AppSpacing.sm) {
                memberChip(nil, name: String(localized: "family.tasks.member_all"))
                ForEach(viewModel.members) { member in
                    let name = member.memberID == viewModel.currentMemberID
                        ? String(localized: "family.tasks.member_you") : firstName(member.name)
                    memberChip(member.memberID, name: name)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityIdentifier("family.tasks.member_filters")
    }

    private func memberChip(_ id: UUID?, name: String) -> some View {
        let selected = viewModel.selectedMemberID == id
        return Button {
            Task { await viewModel.applyMember(id) }
        } label: {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                if let id {
                    MemberAvatarView(name: memberName(id) ?? name, color: colors(for: id).tint, size: 24)
                }
                Text(name)
            }
            .padding(.leading, id == nil ? AppSpacing.base : AppSpacing.sm)
            .padding(.trailing, AppSpacing.base)
            .familyChip(isSelected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id.map { "family.tasks.member.\($0.uuidString)" } ?? "family.tasks.member.all")
    }

    private func colors(for memberID: UUID) -> FamilyMemberPalette.Colors {
        FamilyMemberPalette.colors(for: memberID, isCurrentMember: memberID == viewModel.currentMemberID)
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    // MARK: Period summary

    private var periodSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(rangeLabel)
                .font(.app(.title3))
                .foregroundStyle(Color.App.Text.primary)
                .accessibilityIdentifier("family.tasks.period")
            if FamilyOverviewDates.containsToday(viewModel.range, timeZoneID: viewModel.timeZoneID) {
                Text(FamilyOverviewDates.todaySubtitle(for: viewModel.range, timeZoneID: viewModel.timeZoneID))
                    .font(.app(.subtitleStrong))
                    .foregroundStyle(Color.App.Text.primary)
            }
            if viewModel.status != .all {
                Label(statusFilterTitle(viewModel.status), systemImage: "line.3.horizontal.decrease")
                    .font(.app(.noteStrong))
                    .foregroundStyle(Color.App.Text.highlight)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.App.Background.cardHighlight, in: Capsule())
                    .padding(.top, AppSpacing.xxs)
                    .accessibilityIdentifier("family.tasks.active_status")
            }
        }
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: States

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Capsule()
                .fill(Color.App.Background.subtle)
                .frame(width: 120, height: 12)
            RoundedRectangle(cornerRadius: AppRadius.cardBoard)
                .fill(Color.App.Background.subtle)
                .frame(height: 156)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.overview.loading")
        .accessibilityIdentifier("family.tasks.loading")
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.App.Action.primary)
                .accessibilityHidden(true)
            Text("family.tasks.empty")
                .font(.app(.cardTitle))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxxl)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("family.tasks.empty")
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text("family.tasks.error")
                    .font(.app(.subtitle))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.App.Text.primary)
            .accessibilityElement(children: .combine)
            Button("family.member.detail.retry") { Task { await viewModel.load() } }
                .buttonStyle(AppPillButtonStyle(kind: .primary))
                .disabled(viewModel.isLoading)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .accessibilityIdentifier("family.tasks.error")
    }

    /// Rows already on screen stay usable; a failed refresh only adds this recovery.
    private var refreshFailureBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            InlineFeedbackBanner(message: String(localized: "family.tasks.error"))
            Button("family.member.detail.retry") { Task { await viewModel.load() } }
                .font(.app(.subtitleStrong))
                .foregroundStyle(Color.App.Text.highlight)
                .frame(minHeight: 44)
                .disabled(viewModel.isLoading)
        }
        .accessibilityIdentifier("family.tasks.error")
    }

    // MARK: Sections

    @ViewBuilder
    private func taskSection(_ status: TaskStatus) -> some View {
        let rows = viewModel.items.filter { $0.displayStatus == status }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                let count = viewModel.count(for: statusFilter(status))
                let heading = count.map {
                    String(format: String(localized: "family.tasks.section_count"),
                           statusTitle(status).uppercased(), $0)
                } ?? statusTitle(status).uppercased()
                Text(heading)
                    .font(.app(.noteStrong))
                    .foregroundStyle(Color.App.Text.secondary)
                    .padding(.leading, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.App.Border.separator)
                                .frame(height: 1)
                                .padding(.leading, AppSpacing.lg + 24 + AppSpacing.md)
                        }
                        let item = rows[index]
                        Button {
                            onOpenTask(item.id)
                        } label: {
                            taskRow(item)
                        }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .appCard(cornerRadius: AppRadius.cardBoard)
            }
        }
    }

    private func taskRow(_ item: FamilyTaskItem) -> some View {
        let isCompleted = item.displayStatus == .completed
        return HStack(spacing: AppSpacing.md) {
            FamilyTaskStatusIcon(status: item.displayStatus)
            Text(item.task.title)
                .font(.app(.body))
                .foregroundStyle(isCompleted ? Color.App.Text.secondary : Color.App.Text.primary)
                .strikethrough(isCompleted, color: Color.App.Text.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            assignees(item.task.assigneeIDs)
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
        .accessibilityLabel(rowAccessibilityLabel(item))
        .accessibilityHint("tasks.personal.openDetailHint")
        .accessibilityIdentifier("family.tasks.row.\(item.id.uuidString)")
    }

    @ViewBuilder
    private func assignees(_ ids: [UUID]) -> some View {
        if ids.isEmpty {
            HStack(spacing: AppSpacing.xs) {
                // Figma shows a bare figure, no enclosing circle (870:23195).
                Image(systemName: "person")
                    .font(.system(size: 16))
                Text("family.tasks.unassigned")
                    .font(.app(.note))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.App.Text.secondary)
            .accessibilityHidden(true)
        } else {
            HStack(spacing: -6) {
                ForEach(Array(ids.prefix(3)), id: \.self) { id in
                    MemberAvatarView(name: memberName(id) ?? "?", color: colors(for: id).tint, size: 24)
                        .overlay(Circle().strokeBorder(Color.App.Background.card, lineWidth: 1.5))
                }
                if ids.count > 3 {
                    Text("+\(ids.count - 3)")
                        .font(.app(.captionStrong))
                        .foregroundStyle(Color.App.Text.primary)
                        .frame(width: 24, height: 24)
                        .background(Color.App.Background.cardHighlight, in: Circle())
                        .overlay(Circle().strokeBorder(Color.App.Background.card, lineWidth: 1.5))
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func memberName(_ id: UUID) -> String? {
        if id == viewModel.currentMemberID { return String(localized: "family.tasks.member_you") }
        return viewModel.members.first(where: { $0.memberID == id })?.name
    }

    private func rowAccessibilityLabel(_ item: FamilyTaskItem) -> String {
        let names = item.task.assigneeIDs.isEmpty
            ? String(localized: "family.tasks.unassigned")
            : item.task.assigneeIDs.map {
                memberName($0) ?? String(localized: "family.tasks.unknown_member")
            }.joined(separator: ", ")
        return "\(item.task.title), \(statusTitle(item.displayStatus)), \(names)"
    }

    private func statusSymbol(_ status: TaskStatus) -> String {
        switch status {
        case .pending: "circle"
        case .awaitingConfirmation: "clock"
        case .completed: "checkmark.circle.fill"
        }
    }

    private func statusFilter(_ status: TaskStatus) -> FamilyTaskStatusFilter {
        switch status {
        case .pending: .pending
        case .awaitingConfirmation: .awaitingConfirmation
        case .completed: .completed
        }
    }

    private func statusTitle(_ status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "family.tasks.status.pending")
        case .awaitingConfirmation: String(localized: "family.tasks.status.awaiting")
        case .completed: String(localized: "family.tasks.status.completed")
        }
    }

    private func statusFilterTitle(_ status: FamilyTaskStatusFilter) -> LocalizedStringKey {
        switch status {
        case .all: "family.tasks.status.all"
        case .pending: "family.tasks.status.pending"
        case .awaitingConfirmation: "family.tasks.status.awaiting"
        case .completed: "family.tasks.status.completed"
        }
    }

    /// Reuses TEL-050's formatter (FamilyOverviewView.swift) so a single day collapses to one date
    /// instead of "D a D" — TEL-011's own copy of this logic had drifted and lost that case.
    private var rangeLabel: String {
        FamilyOverviewDates.rangeTitle(viewModel.range, timeZoneID: viewModel.timeZoneID)
    }

    private var reportWeekLabel: String {
        if viewModel.reportSpansMultipleWeeks { return String(localized: "family.report.select_week") }
        guard let start = civilDate(viewModel.range.startDate) else { return "" }
        let weekday = familyCalendar.component(.weekday, from: start)
        let monday = familyCalendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: start) ?? start
        let sunday = familyCalendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        return String(format: String(localized: "family.report.menu_week"),
                      dateText(monday, pattern: "d"),
                      dateText(sunday, pattern: "d"),
                      dateText(sunday, pattern: "MMM"))
    }

    private var familyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: viewModel.timeZoneID) ?? .current
        return calendar
    }

    private func civilDate(_ wire: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = familyCalendar
        formatter.timeZone = familyCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: wire)
    }

    private func dateText(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = familyCalendar
        formatter.timeZone = familyCalendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private func generateReport() async {
        guard !isGeneratingReport else { return }
        isGeneratingReport = true
        reportFailed = false
        defer { isGeneratingReport = false }
        do {
            reportFile = ReportFile(url: try await viewModel.generateCurrentWeekReport())
        } catch {
            reportFailed = true
        }
    }
}

private struct ReportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct FamilyReportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
