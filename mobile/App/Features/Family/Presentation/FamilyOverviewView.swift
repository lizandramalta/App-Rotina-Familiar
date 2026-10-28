import SwiftUI

/// TEL-050 — Família (SPEC-009 CA-05/CA-12, UX-009 §2–§5; Figma 372:4825/372:5195).
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
            VStack(alignment: .leading, spacing: 18) {
                header
                if let overview = viewModel.overview {
                    period(overview)
                    members(overview.members)
                    progressCard(overview)
                    incentiveCards(overview)
                } else if viewModel.isLoadingOverview {
                    loadingContent
                }
                if viewModel.overviewFailed || viewModel.errorMessage != nil {
                    failureCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 32)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("family.members.list")
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(viewModel.familyName.isEmpty ? String(localized: "family.overview.title") : viewModel.familyName)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showsRangeFilter = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
            .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
            .disabled(viewModel.overview == nil)
            .accessibilityLabel("family.period.filter_title")
            .accessibilityIdentifier("family.overview.range_filter")

            if viewModel.canConfigureFamily {
                NavigationLink(value: FamilyNavigationRoute.settingsHub) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                .accessibilityLabel("family.settings.title")
                .accessibilityIdentifier("family.navigation.settings_button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func period(_ overview: FamilyOverview) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(FamilyOverviewDates.rangeTitle(overview.range, timeZoneID: viewModel.timeZoneID))
                .font(.title2.bold())
            Text(FamilyOverviewDates.todaySubtitle(timeZoneID: viewModel.timeZoneID))
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isPeriodFocused)
        .accessibilityIdentifier("family.overview.period")
    }

    private func members(_ items: [FamilyMemberProgress]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(items) { member in
                    NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                        memberRing(member)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.member.ring.\(member.id.uuidString.lowercased())")
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityIdentifier("family.overview.member_rings")
    }

    private func memberRing(_ member: FamilyMemberProgress) -> some View {
        let percentage = member.progress.percentage.map { Int($0.rounded()) }
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color(uiColor: .systemGray4), lineWidth: 5)
                if let percentage {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(percentage, 0), 100)) / 100)
                        .stroke(Color(uiColor: .darkGray), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Circle()
                    .fill(Color(uiColor: .systemGray6))
                    .padding(9)
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 68, height: 68)

            Text(member.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(percentage.map { "\($0)%" } ?? String(localized: "family.overview.no_tasks_short"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percentage.map {
            String(format: String(localized: "family.overview.member_progress_accessibility"), member.name, $0)
        } ?? String(format: String(localized: "family.overview.no_tasks_accessibility"), member.name))
        .accessibilityHint("family.overview.member_open_hint")
    }

    private func progressCard(_ overview: FamilyOverview) -> some View {
        Group {
            if viewModel.selectedRange != nil {
                NavigationLink(value: FamilyNavigationRoute.familyTasks) {
                    progressCardContent(overview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("family.overview.all_tasks")
            } else {
                progressCardContent(overview)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("family.overview.progress")
    }

    private func progressCardContent(_ overview: FamilyOverview) -> some View {
        let progress = overview.progress
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 18))
                Text("family.tasks.title")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                if progress.total > 0 {
                    Text(String(format: String(localized: "family.overview.completed_short"), progress.completed, progress.total))
                        .font(.title.bold())
                    Text(String(
                        format: String(localized: "family.overview.progress_subtitle"),
                        Int((progress.percentage ?? 0).rounded())
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text("family.overview.no_tasks")
                        .font(.title3.weight(.semibold))
                }
            }

            progressBar(progress)

            VStack(spacing: 9) {
                statusRow("family.tasks.status.completed", icon: "checkmark.circle.fill", count: progress.completed)
                if viewModel.canConfigureFamily {
                    statusRow("family.tasks.status.awaiting", icon: "circle.dotted", count: progress.awaitingConfirmation)
                }
                statusRow("family.tasks.status.pending", icon: "circle", count: progress.pending)
            }
        }
        .foregroundStyle(.primary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private func progressBar(_ progress: FamilyProgress) -> some View {
        if progress.total == 0 {
            Capsule().fill(Color(uiColor: .systemGray4)).frame(height: 10)
        } else {
            GeometryReader { proxy in
                let parts = [progress.completed, viewModel.canConfigureFamily ? progress.awaitingConfirmation : 0, progress.pending]
                    .filter { $0 > 0 }
                let width = max(0, proxy.size.width - CGFloat(max(0, parts.count - 1)) * 3)
                HStack(spacing: 3) {
                    if progress.completed > 0 {
                        Capsule().fill(Color.primary)
                            .frame(width: width * CGFloat(progress.completed) / CGFloat(progress.total))
                    }
                    if viewModel.canConfigureFamily && progress.awaitingConfirmation > 0 {
                        Capsule().fill(Color(uiColor: .systemGray2))
                            .frame(width: width * CGFloat(progress.awaitingConfirmation) / CGFloat(progress.total))
                    }
                    if progress.pending > 0 {
                        Capsule().fill(Color(uiColor: .systemGray4))
                            .frame(width: width * CGFloat(progress.pending) / CGFloat(progress.total))
                    }
                }
            }
            .frame(height: 10)
        }
    }

    private func statusRow(_ title: LocalizedStringKey, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .frame(width: 18)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private func incentiveCards(_ overview: FamilyOverview) -> some View {
        if let today = viewModel.todayOverview {
            let completedToday = today.members.filter { $0.progress.total > 0 && $0.progress.completed == $0.progress.total }
            ForEach(completedToday) { member in
                incentiveCard(member: member, title: "family.incentive.completed_today", icon: "hand.thumbsup.fill")
            }
        }
        if overview.members.count > 1, let maximum = overview.members.map(\.progress.total).max(), maximum > 0 {
            ForEach(overview.members.filter { $0.progress.total == maximum }) { member in
                if member.id == viewModel.currentMemberID {
                    ownMostTasksCard(member: member)
                } else {
                    incentiveCard(member: member, title: "family.incentive.most_tasks", icon: "hands.clap.fill")
                }
            }
        }
    }

    private func ownMostTasksCard(member: FamilyMemberProgress) -> some View {
        NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
            HStack(spacing: 12) {
                Image(systemName: "hands.clap.fill")
                    .font(.title2)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 8) {
                    Text("family.incentive.my_most_tasks")
                        .font(.headline)
                    Text("family.incentive.view_my_tasks")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("family.incentive.own_most_tasks")
    }

    private func incentiveCard(member: FamilyMemberProgress, title: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(member.name).font(.headline)
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if let summary = viewModel.applauseSummary[member.id], summary.count > 0 {
                Text(applauseCaption(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                NavigationLink(value: FamilyNavigationRoute.member(member.id)) {
                    Text(String(format: String(localized: "family.incentive.view_tasks"), member.name))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
                if viewModel.canConfigureFamily && member.id != viewModel.currentMemberID {
                    Button {
                        Task { await viewModel.sendApplause(to: member.id) }
                    } label: {
                        if viewModel.sendingApplauseIDs.contains(member.id) {
                            ProgressView()
                        } else {
                            Text(viewModel.sentApplauseIDs.contains(member.id)
                                 ? "family.incentive.sent" : "family.incentive.congratulate")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .disabled(viewModel.sendingApplauseIDs.contains(member.id))
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .accessibilityIdentifier("family.incentive.congratulate.\(member.id.uuidString.lowercased())")
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func applauseCaption(_ summary: FamilyApplauseSummary) -> String {
        if summary.sentByMe {
            if summary.count == 1 { return String(localized: "family.incentive.only_you") }
            let key = summary.count == 2
                ? String(localized: "family.incentive.you_plus_one")
                : String(localized: "family.incentive.you_plus_many")
            return String(format: key, summary.count - 1)
        }
        let key = summary.count == 1
            ? String(localized: "family.incentive.one_person")
            : String(localized: "family.incentive.many_people")
        return String(format: key, summary.count)
    }

    private var kidsConfirmationsCard: some View {
        NavigationLink {
            if let queue = viewModel.makeKidsReviewQueue() {
                KidsReviewQueueView(viewModel: queue)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .frame(width: 20)
                Text("family.overview.kids_confirmations")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("family.overview.kids_confirmations")
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 170, height: 28)
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .stroke(Color(uiColor: .systemGray5), lineWidth: 5)
                        .frame(width: 68, height: 68)
                        .frame(width: 78)
                }
            }
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(height: 210)
        }
        .accessibilityLabel("family.overview.loading")
        .accessibilityIdentifier("family.overview.progress_loading")
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("family.overview.error_load", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .accessibilityFocused($isErrorFocused)
            Button("family.member.detail.retry") {
                Task { await viewModel.loadInitial() }
            }
            .font(.subheadline.weight(.semibold))
            .disabled(viewModel.isLoading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("family.members.error")
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

    static func todaySubtitle(timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar(timeZoneID)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return String(format: String(localized: "family.overview.today_subtitle"), formatter.string(from: .now))
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
