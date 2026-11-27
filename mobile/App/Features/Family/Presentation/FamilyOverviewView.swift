import SwiftUI

/// TEL-050 — Família (SPEC-009 CA-05/CA-12, UX-009 §2–§5; Figma "04 · Aba Família · Alta fidelidade" 879:13129).
struct FamilyOverviewView: View {
    @State private var viewModel: FamilyOverviewViewModel
    @State private var showsRangeFilter = false
    @AccessibilityFocusState private var isPeriodFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool
    init(viewModel: FamilyOverviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                header
                if let overview = viewModel.overview {
                    period(overview)
                    if viewModel.overviewFailed {
                        refreshFailureBanner
                    }
                    members(overview.members)
                    progressCard(overview)
                    incentiveSection(overview)
                    if viewModel.canReviewKidsConfirmations {
                        kidsConfirmationsCard
                    }
                } else if viewModel.isLoadingOverview {
                    loadingContent
                }
                if viewModel.overview == nil, viewModel.overviewFailed || viewModel.errorMessage != nil {
                    failureCard
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            // The shell's safe-area inset lifts the content above the floating tab bar; this extra margin keeps
            // the last card (Confirmações Kids) fully clear of the bar's shadow and glass edge.
            .padding(.bottom, AppSpacing.colossal + AppSpacing.md)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("family.members.list")
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
        .sheet(isPresented: $showsRangeFilter) {
            if let overview = viewModel.overview {
                FamilyRangeFilterSheet(
                    range: overview.range,
                    firstDate: overview.familyCreatedAt,
                    timeZoneID: viewModel.timeZoneID,
                    taskCount: overview.progress.total,
                    countProvider: { range in try await viewModel.previewTaskCount(for: range) }
                ) { range in
                    Task { await viewModel.applyRange(range) }
                }
            }
        }
        .onChange(of: viewModel.selectedRange) { oldValue, newValue in
            if oldValue != nil && newValue != oldValue { isPeriodFocused = true }
        }
        .onChange(of: viewModel.overviewFailed) { _, failed in
            if failed { isErrorFocused = true }
        }
        .alert("family.applause.error.title", isPresented: Binding(
            get: { viewModel.applauseFailed },
            set: { if !$0 { viewModel.dismissApplauseFailure() } }
        )) {
            Button("OK") { viewModel.dismissApplauseFailure() }
        } message: {
            Text("family.applause.error.message")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(viewModel.familyName.isEmpty ? String(localized: "family.overview.title") : viewModel.familyName)
                .font(.app(.titleLarge))
                .foregroundStyle(Color.App.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Button {
                showsRangeFilter = true
            } label: {
                FamilyCircleIconLabel(
                    systemImage: "line.3.horizontal.decrease",
                    isActive: isCustomRangeActive
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.overview == nil)
            .accessibilityLabel("family.period.filter_title")
            .accessibilityIdentifier("family.overview.range_filter")

            if viewModel.canConfigureFamily {
                NavigationLink(value: FamilyNavigationRoute.settingsHub) {
                    FamilyCircleIconLabel(systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("family.settings.title")
                .accessibilityIdentifier("family.navigation.settings_button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isCustomRangeActive: Bool {
        guard let overview = viewModel.overview else { return false }
        return FamilyRangeFilterSheet.isCustomRange(
            overview.range, familyCreatedAt: overview.familyCreatedAt, timeZoneID: viewModel.timeZoneID
        )
    }

    private func period(_ overview: FamilyOverview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(FamilyOverviewDates.rangeTitle(overview.range, timeZoneID: viewModel.timeZoneID))
                .font(.app(.title2))
            if FamilyOverviewDates.containsToday(overview.range, timeZoneID: viewModel.timeZoneID) {
                Text(FamilyOverviewDates.todaySubtitle(for: overview.range, timeZoneID: viewModel.timeZoneID))
                    .font(.app(.subtitleStrong))
            }
        }
        .foregroundStyle(Color.App.Text.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isPeriodFocused)
        .accessibilityIdentifier("family.overview.period")
    }

    // MARK: Members

    private func members(_ items: [FamilyMemberProgress]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ForEach(items) { member in
                    NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                        MemberProgressRingView(member: member, colors: colors(for: member.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.member.ring.\(member.id.uuidString.lowercased())")
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .scrollClipDisabled()
        .accessibilityIdentifier("family.overview.member_rings")
    }

    private func colors(for memberID: UUID) -> FamilyMemberPalette.Colors {
        FamilyMemberPalette.colors(for: memberID, isCurrentMember: memberID == viewModel.currentMemberID)
    }

    // MARK: Progress

    private func progressCard(_ overview: FamilyOverview) -> some View {
        Group {
            if viewModel.selectedRange != nil {
                NavigationLink(value: FamilyNavigationRoute.familyTasks) {
                    progressCardContent(overview)
                }
                .buttonStyle(.plain)
            } else {
                progressCardContent(overview)
            }
        }
        .accessibilityIdentifier("family.overview.progress")
    }

    /// Figma 879:13356 › "Progresso da família" (879:13406): header, chalk donut + fraction, full-width legend.
    private func progressCardContent(_ overview: FamilyOverview) -> some View {
        let progress = overview.progress
        return VStack(alignment: .leading, spacing: AppSpacing.base) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Image(systemName: "person.2")
                    .foregroundStyle(Color.App.Text.primary)
                    .accessibilityHidden(true)
                Text("family.tasks.title")
                    .font(.app(.subtitleStrong))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .center, spacing: AppSpacing.base) {
                MemberCompletionStarView(members: overview.members, total: progress.total, colorFor: { colors(for: $0).tint })
                VStack(alignment: .leading, spacing: AppSpacing.xs + AppSpacing.xxs) {
                    if progress.total > 0 {
                        Text(String(format: String(localized: "family.overview.completed_fraction"), progress.completed, progress.total))
                            .font(.app(.numberLarge))
                            .foregroundStyle(Color.App.Text.primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .accessibilityLabel(String(
                                format: String(localized: "family.overview.completed_total"), progress.completed, progress.total
                            ))
                        Text("family.overview.completed_caption")
                            .font(.app(.subtitleStrong))
                            .foregroundStyle(Color.App.Text.highlight)
                    } else {
                        Text("family.overview.no_tasks")
                            .font(.app(.title3))
                            .foregroundStyle(Color.App.Text.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                statusCountRow("family.tasks.status.completed", count: progress.completed)
                let contributors = overview.members.filter { $0.progress.completed > 0 }
                if !contributors.isEmpty {
                    memberLegendRow(contributors)
                }
                if viewModel.canConfigureFamily {
                    statusCountRow("family.tasks.status.awaiting", count: progress.awaitingConfirmation)
                }
                statusCountRow("family.tasks.status.pending", count: progress.pending)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .fill(Color.App.Background.cardHighlight)
        )
        .overlay {
            ChalkThickBorder(
                shape: RoundedRectangle(cornerRadius: AppRadius.pill),
                color: Color.App.Border.cardHighlight,
                width: 4
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.pill))
    }

    private func statusCountRow(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(.app(.subtitle))
            Spacer(minLength: AppSpacing.sm)
            Text("\(count)")
                .font(.app(.subtitleStrong))
        }
        .foregroundStyle(Color.App.Text.primary)
        .accessibilityElement(children: .combine)
    }

    /// Names which member each star band belongs to (Figma 879:13406): colored dot + first name,
    /// one per contributor, in the same server order the star stacks them in.
    private func memberLegendRow(_ members: [FamilyMemberProgress]) -> some View {
        FamilyFlowLayout(spacing: AppSpacing.md) {
            ForEach(members) { member in
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(colors(for: member.id).tint)
                        .frame(width: 10, height: 10)
                    Text(firstName(member.name))
                        .font(.app(.subtitle))
                }
            }
        }
        .foregroundStyle(Color.App.Text.primary)
        .accessibilityElement(children: .combine)
    }

    // MARK: Atualizações (incentives)

    private func incentiveSection(_ overview: FamilyOverview) -> some View {
        let completedToday = (viewModel.todayOverview?.members.filter {
            $0.progress.total > 0 && $0.progress.completed == $0.progress.total
        } ?? []).filter { !isDismissedAfterApplause($0.id) }
        // "Teve muitas tarefas" has no Parabenizar, so it never leaves after congratulating (Figma 920:8200).
        var mostTasks: [FamilyMemberProgress] = []
        if overview.members.count > 1, let maximum = overview.members.map(\.progress.total).max(), maximum > 0 {
            mostTasks = overview.members.filter { $0.progress.total == maximum }
        }
        let hiddenIDs = Set(overview.members.map(\.id).filter(isDismissedAfterApplause))
        return Group {
            // No visible card left: the "Atualizações" title goes too, never an empty section.
            if !completedToday.isEmpty || !mostTasks.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("family.overview.updates")
                        .font(.app(.title2))
                        .foregroundStyle(Color.App.Text.primary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(completedToday) { member in
                        incentiveCard(
                            member: member,
                            message: String(format: String(localized: "family.incentive.completed_today"), member.name),
                            prompt: "family.incentive.completed_today_prompt",
                            action: .congratulate
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    ForEach(mostTasks) { member in
                        if member.id == viewModel.currentMemberID {
                            ownMostTasksCard(member: member)
                        } else {
                            incentiveCard(
                                member: member,
                                message: mostTasksMessage(for: overview.range, name: member.name),
                                prompt: "family.incentive.most_tasks_prompt",
                                action: .viewTasks
                            )
                        }
                    }
                }
            }
        }
        .animation(.snappy, value: hiddenIDs)
    }

    /// "<Nome> está com muitas tarefas hoje/nesta semana/neste período." (Figma 920:8200): the suffix
    /// matches the visible range exactly for a single day or a calendar week, and falls back to the
    /// generic phrasing UX-009 already uses for the own-user variant for any other custom range.
    private func mostTasksMessage(for range: FamilyDateRange, name: String) -> String {
        let key: String.LocalizationValue
        switch FamilyOverviewDates.dayCount(in: range, timeZoneID: viewModel.timeZoneID) {
        case 1: key = "family.incentive.most_tasks_today"
        case 7: key = "family.incentive.most_tasks_week"
        default: key = "family.incentive.most_tasks"
        }
        return String(format: String(localized: key), name)
    }

    /// Only the "<Nome> terminou todas as tarefas de hoje!" card (the one with Parabenizar) leaves
    /// after an Administrator congratulates another member, and stays hidden on reload (RN60/RN61,
    /// SPEC-009 E-13).
    private func isDismissedAfterApplause(_ memberID: UUID) -> Bool {
        viewModel.canConfigureFamily && memberID != viewModel.currentMemberID && viewModel.isMemberCongratulated(memberID)
    }

    private func updateCardSurface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.updateCard)
                    .fill(Color.App.Background.cardUpdate)
                    .shadow(color: Color.App.Action.primary.opacity(0.07), radius: 7.5, y: 6)
            )
            .chalkStrokeBorder(RoundedRectangle(cornerRadius: AppRadius.updateCard), color: Color.App.Border.card, lineWidth: 2)
    }

    private func ownMostTasksCard(member: FamilyMemberProgress) -> some View {
        NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
            updateCardSurface {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("family.incentive.my_most_tasks")
                        .font(.app(.bodyStrong))
                        .foregroundStyle(Color.App.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                        Image(systemName: "person.2").accessibilityHidden(true)
                        Text("family.incentive.view_my_tasks")
                    }
                    .modifier(CompactActionLabel(kind: .secondary))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.updateCard))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("family.incentive.own_most_tasks")
    }

    /// Each update card carries one action (Figma 920:8186 / 920:8200): "<Nome> terminou todas as
    /// tarefas de hoje!" offers Parabenizar (Administrator, another member); "<Nome> está com muitas
    /// tarefas ..." offers "Ver tarefas de <Nome>". The name is part of the bold sentence itself, not
    /// a separate heading line — only the prompt below it is secondary-colored.
    private enum IncentiveAction { case congratulate, viewTasks }

    private func incentiveCard(
        member: FamilyMemberProgress, message: String, prompt: LocalizedStringKey, action: IncentiveAction
    ) -> some View {
        updateCardSurface {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    MemberAvatarView(name: member.name, color: colors(for: member.id).tint, size: 40)
                    Text(message)
                        .font(.app(.cardTitle))
                        .foregroundStyle(Color.App.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                Text(prompt)
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
                switch action {
                case .congratulate:
                    if viewModel.canConfigureFamily && member.id != viewModel.currentMemberID {
                        congratulateButton(member)
                    }
                case .viewTasks:
                    NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                        HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                            Image(systemName: "person.2").accessibilityHidden(true)
                            Text(String(format: String(localized: "family.incentive.view_tasks"), firstName(member.name)))
                        }
                        .modifier(CompactActionLabel(kind: .secondary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Always "Parabenizar": once the server confirms, the whole card leaves the screen (RN60/RN61).
    private func congratulateButton(_ member: FamilyMemberProgress) -> some View {
        let isSending = viewModel.sendingApplauseIDs.contains(member.id)
        return Button {
            Task { await viewModel.sendApplause(to: member.id) }
        } label: {
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                if isSending {
                    ProgressView().tint(Color.App.Text.onAction)
                } else {
                    Image(systemName: "hands.clap").accessibilityHidden(true)
                    Text("family.incentive.congratulate")
                        .lineLimit(1)
                }
            }
            .modifier(CompactActionLabel(kind: .primary))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityIdentifier("family.incentive.congratulate.\(member.id.uuidString.lowercased())")
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    // MARK: Confirmações Kids

    private var kidsConfirmationsCard: some View {
        NavigationLink {
            if let queue = viewModel.makeKidsReviewQueue() {
                KidsReviewQueueView(viewModel: queue)
                    .hidesAppTabBar()
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Outline shield aligned with the title, no circle behind it (Figma 879:13443).
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.App.Action.primary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("family.overview.kids_confirmations")
                    .font(.app(.cardTitle))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64)
            .appCard(cornerRadius: AppRadius.cardBoard)
            // The whole card is tappable, including its empty middle.
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.cardBoard))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("family.overview.kids_confirmations")
    }

    // MARK: States

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            RoundedRectangle(cornerRadius: AppRadius.banner)
                .fill(Color.App.Background.subtle)
                .frame(width: 170, height: 26)
            HStack(spacing: AppSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(Color.App.Background.subtle)
                            .frame(width: 68, height: 68)
                        Capsule()
                            .fill(Color.App.Background.subtle)
                            .frame(width: 48, height: 10)
                    }
                    .frame(width: 78)
                }
            }
            RoundedRectangle(cornerRadius: AppRadius.cardBoard)
                .fill(Color.App.Background.subtle)
                .frame(height: 170)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.overview.loading")
        .accessibilityIdentifier("family.overview.progress_loading")
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text("family.overview.error_load")
                    .font(.app(.subtitle))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.App.Text.primary)
            .accessibilityElement(children: .combine)
            .accessibilityFocused($isErrorFocused)
            Button("family.member.detail.retry") {
                Task { await viewModel.loadInitial() }
            }
            .buttonStyle(AppPillButtonStyle(kind: .primary))
            .disabled(viewModel.isLoading)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .accessibilityIdentifier("family.members.error")
    }

    /// Confirmed content stays on screen; a failed refresh only adds this non-blocking recovery.
    private var refreshFailureBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            InlineFeedbackBanner(message: String(localized: "family.overview.error_load"))
                .accessibilityFocused($isErrorFocused)
            Button("family.member.detail.retry") {
                Task { await viewModel.loadInitial() }
            }
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Text.highlight)
            .frame(minHeight: 44)
            .disabled(viewModel.isLoading)
        }
        .accessibilityIdentifier("family.overview.refresh_error")
    }
}

/// Compact action of the "Atualizações" cards (Figma 920:8159/920:8174): hugs its text, 14 pt corners, 2 pt
/// chalk `Action.primary` border; visually compact but with a 44 pt minimum touch target.
private struct CompactActionLabel: ViewModifier {
    enum Kind { case primary, secondary }
    let kind: Kind

    func body(content: Content) -> some View {
        content
            .font(.app(.subtitleStrong))
            .foregroundStyle(kind == .primary ? Color.App.Text.onAction : Color.App.Text.highlight)
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: 44)
            .background(
                kind == .primary ? Color.App.Action.primarySoft : Color.App.Background.card,
                in: RoundedRectangle(cornerRadius: AppRadius.card)
            )
            .chalkStrokeBorder(RoundedRectangle(cornerRadius: AppRadius.card), color: Color.App.Action.primary, lineWidth: 2)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        // No fixed width: it hugs short labels and can still wrap at large Dynamic Type sizes.
    }
}

enum FamilyOverviewDates {
    static func rangeTitle(_ range: FamilyDateRange, timeZoneID: String) -> String {
        let calendar = calendar(timeZoneID)
        guard let start = date(range.startDate, calendar: calendar),
              let end = date(range.endDate, calendar: calendar) else {
            return "\(range.startDate) – \(range.endDate)"
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        if calendar.isDate(start, inSameDayAs: end) { return formatter.string(from: start) }

        let startParts = calendar.dateComponents([.year, .month, .day], from: start)
        let endParts = calendar.dateComponents([.year, .month, .day], from: end)
        if startParts.month == endParts.month && startParts.year == endParts.year {
            formatter.setLocalizedDateFormatFromTemplate("MMM")
            return String(
                format: String(localized: "family.overview.range_same_month"),
                startParts.day ?? 1,
                endParts.day ?? 1,
                formatter.string(from: end)
            )
        }
        return String(format: String(localized: "family.overview.range_other_month"), formatter.string(from: start), formatter.string(from: end))
    }

    /// "Hoje · …" is shown only when today belongs to the visible range (UX-009 TEL-050/TEL-011).
    static func containsToday(_ range: FamilyDateRange, timeZoneID: String, now: Date = .now) -> Bool {
        let calendar = calendar(timeZoneID)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        return range.startDate <= today && today <= range.endDate
    }

    /// Inclusive number of days in `range`; 1 for a single day or an unreadable range.
    static func dayCount(in range: FamilyDateRange, timeZoneID: String) -> Int {
        let calendar = calendar(timeZoneID)
        guard let start = date(range.startDate, calendar: calendar),
              let end = date(range.endDate, calendar: calendar),
              let days = calendar.dateComponents([.day], from: start, to: end).day else { return 1 }
        return max(1, days + 1)
    }

    /// "Hoje · terça-feira" for a single day (the date is already the title above it); with two or more days,
    /// "Hoje · terça-feira, 17 de novembro" (UX-009 TEL-050/TEL-011).
    static func todaySubtitle(for range: FamilyDateRange, timeZoneID: String, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar(timeZoneID)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(dayCount(in: range, timeZoneID: timeZoneID) < 2 ? "EEEE" : "EEEE d MMMM")
        return String(format: String(localized: "family.overview.today_subtitle"), formatter.string(from: now))
    }

    private static func calendar(_ timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    private static func date(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
