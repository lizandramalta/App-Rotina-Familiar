import SwiftUI

/// TEL-010 (adult) and TEL-040 (Kids) — own daily checklist (SPEC-009 Fase 1, UX-009 §2/§3).
/// Never shows a Semana selector (CA-01). Row tap opens TEL-012 for both audiences: SPEC-011
/// requires Kids to reach their own completed task to reopen it (TEL-012/MOD-006).
struct DailyTaskListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: DailyTaskListViewModel
    @State private var visibleWeekStart: Date
    private let currentMemberID: UUID
    let refreshRevision: Int
    let onSelectTask: (UUID) -> Void
    let onCreateTask: () -> Void
    /// SCRUM-103: internal access to TEL-052, shown on today's list only (E-1).
    let recognitionEntry: WeeklyRecognitionEntryViewModel?
    let onOpenRecognition: (UUID) -> Void
    /// Trailing header control (TEL-040: avatar that opens TEL-030); the adult header shows "+".
    let headerAccessory: AnyView?

    /// UX-009 §5: on period change, focus follows the updated header; on failure, it follows the
    /// error message and retry action. Same mechanism already used in EntryView.
    @AccessibilityFocusState private var isHeaderFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool
    @AccessibilityFocusState private var isMissionWarningFocused: Bool
    @AccessibilityFocusState private var focusedTaskID: UUID?

    init(
        audience: TaskAudience,
        role: MemberRole,
        currentMemberID: UUID,
        repository: any TaskRepository,
        familyRepository: (any FamilyRepository)? = nil,
        accessTokenProvider: @escaping AccessTokenProvider,
        refreshRevision: Int = 0,
        onSelectTask: @escaping (UUID) -> Void,
        onCreateTask: @escaping () -> Void,
        recognitionEntry: WeeklyRecognitionEntryViewModel? = nil,
        onOpenRecognition: @escaping (UUID) -> Void = { _ in },
        headerAccessory: AnyView? = nil
    ) {
        let model = DailyTaskListViewModel(
            audience: audience,
            role: role,
            currentMemberID: currentMemberID,
            repository: repository,
            familyRepository: familyRepository,
            accessTokenProvider: accessTokenProvider
        )
        _viewModel = State(initialValue: model)
        _visibleWeekStart = State(initialValue: Self.startOfSundayWeek(containing: model.selectedDate))
        self.currentMemberID = currentMemberID
        self.refreshRevision = refreshRevision
        self.onSelectTask = onSelectTask
        self.onCreateTask = onCreateTask
        self.recognitionEntry = recognitionEntry
        self.onOpenRecognition = onOpenRecognition
        self.headerAccessory = headerAccessory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.base) {
                header
                carousel
                if let featured = recognitionEntry?.featured, viewModel.isToday(viewModel.selectedDate) {
                    WeeklyRecognitionEntryCard(recognition: featured, onOpen: onOpenRecognition)
                }
                ForEach(viewModel.receivedApplause) { applause in
                    applauseCard(applause)
                }
                Group {
                    if viewModel.isLoading, viewModel.items.isEmpty, viewModel.progress == nil {
                        loadingSkeleton
                    } else if viewModel.loadFailed, viewModel.items.isEmpty {
                        failureState
                    } else if viewModel.isEmpty {
                        if viewModel.audience == .adult {
                            VStack(alignment: .leading, spacing: AppSpacing.base) {
                                progressCard
                                emptyState
                            }
                        } else {
                            emptyState
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.base) {
                            progressCard
                            if viewModel.loadFailed {
                                failureState
                            }
                            if viewModel.actionFailure != nil,
                               viewModel.items.contains(where: { $0.id == viewModel.actionFailureTaskID }) {
                                actionFailureBanner
                            }
                            taskList
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            // The floating tab bar's safe-area inset already lifts the end of the list above it.
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .alert("family.applause.dismiss_error", isPresented: Binding(
            get: { viewModel.applauseDismissFailed },
            set: { if !$0 { viewModel.dismissApplauseFailure() } }
        )) {
            Button("OK") { viewModel.dismissApplauseFailure() }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.missionReopenPrompt != nil },
            set: { if !$0 { viewModel.cancelMissionReopen() } }
        )) {
            if let prompt = viewModel.missionReopenPrompt {
                MissionReopenConfirmationView(
                    prompt: prompt,
                    role: viewModel.audience == .kid ? .kid : viewModel.role,
                    isSubmitting: viewModel.missionReopenTaskID.map { viewModel.actionInFlight.contains($0) } ?? false,
                    isWarningFocused: $isMissionWarningFocused,
                    onConfirm: { viewModel.confirmMissionReopen() },
                    onCancel: { viewModel.cancelMissionReopen() }
                )
            }
        }
        .alert(
            viewModel.actionAlert == .uncertain
                ? "tasks.personal.actionUncertainTitle"
                : "tasks.personal.actionFailedTitle",
            isPresented: Binding(
                get: { viewModel.actionAlert != nil },
                set: { if !$0 { viewModel.dismissActionAlert() } }
            )
        ) {
            if viewModel.actionAlert == .uncertain {
                Button("task.complete.refresh_status") {
                    Task { await viewModel.refreshActionStatus() }
                }
            }
            Button("OK") { viewModel.dismissActionAlert() }
        } message: {
            Text(viewModel.actionAlert == .uncertain
                 ? "tasks.personal.actionError"
                 : "tasks.personal.actionFailedMessage")
        }
        .task(id: refreshRevision) {
            Task { await refreshRecognitionEntry() }
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshReceivedApplause() }
                Task { await refreshRecognitionEntry() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyRecognitionDidArrive)) { _ in
            Task { await refreshRecognitionEntry() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .familyApplauseDidArrive)) { _ in
            Task { await viewModel.refreshReceivedApplause() }
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            visibleWeekStart = Self.startOfSundayWeek(containing: viewModel.selectedDate)
            isHeaderFocused = true
        }
        .onChange(of: viewModel.loadFailed) { _, failed in
            if failed {
                isErrorFocused = true
            }
        }
        .onChange(of: viewModel.actionRevision) { _, _ in
            focusedTaskID = viewModel.lastChangedTaskID
        }
        .onChange(of: viewModel.actionFailure) { _, failure in
            if failure != nil { isErrorFocused = true }
        }
    }

    private func refreshRecognitionEntry() async {
        await recognitionEntry?.refresh()
    }

    private func applauseCard(_ applause: ReceivedFamilyApplause) -> some View {
        let messageFormat = applause.senderNames.count > 1
            ? String(localized: "family.applause.received.message_plural")
            : String(localized: "family.applause.received.message")
        return HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "hands.clap.fill")
                .font(.app(.title2))
                .foregroundStyle(Color.App.Text.highlight)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("family.applause.received.title")
                    .font(.app(.cardTitle))
                Text(String(format: messageFormat,
                    ListFormatter.localizedString(byJoining: applause.senderNames)))
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            Spacer(minLength: 0)
            Button {
                Task { await viewModel.dismissApplause(applause.id) }
            } label: {
                Image(systemName: "xmark")
                    .font(.app(.captionStrong))
                    .frame(width: AppSpacing.huge, height: AppSpacing.huge)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("family.applause.dismiss")
        }
        .foregroundStyle(Color.App.Text.primary)
        .padding(AppSpacing.lg)
        .appCard()
        .accessibilityIdentifier("family.applause.received.\(applause.id.uuidString.lowercased())")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(viewModel.audience == .adult ? "tasks.adult.title" : "destination.myTasks")
                    .font(.app(.titleLarge))
                    .foregroundStyle(Color.App.Text.primary)
                Text(Self.dateSubtitle(
                    for: viewModel.selectedDate,
                    isToday: viewModel.audience == .kid && viewModel.isToday(viewModel.selectedDate)
                ))
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($isHeaderFocused)
            Spacer(minLength: 0)
            if viewModel.audience == .adult {
                CircularAddButton(action: onCreateTask)
                    .accessibilityLabel(Text("tasks.personal.newTask"))
                    .accessibilityIdentifier("tasks.daily.new")
            } else if let headerAccessory {
                headerAccessory
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Carousel (RN49)

    private var carousel: some View {
        TabView(selection: $visibleWeekStart) {
            ForEach(carouselWeekStarts, id: \.self) { weekStart in
                HStack(spacing: 0) {
                    ForEach(0 ..< 7, id: \.self) { offset in
                        if let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: weekStart) {
                            dayButton(for: date)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .tag(weekStart)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: DayCarouselItemView.size.height)
        .accessibilityElement(children: .contain)
    }

    private var carouselWeekStarts: [Date] {
        let calendar = Calendar(identifier: .gregorian)
        let first = Self.startOfSundayWeek(containing: viewModel.familyCreatedAt ?? viewModel.selectedDate)
        let lastDay = calendar.dateInterval(of: .month, for: Date())?.end.addingTimeInterval(-1) ?? Date()
        let last = Self.startOfSundayWeek(containing: lastDay)
        var weeks: [Date] = []
        var week = first
        while week <= last {
            weeks.append(week)
            guard let next = calendar.date(byAdding: .day, value: 7, to: week) else { break }
            week = next
        }
        return weeks
    }

    private static func startOfSundayWeek(containing date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func dayButton(for date: Date) -> some View {
        let isAvailable = viewModel.isDateAvailable(date)
        let isSelected = viewModel.isSelected(date)
        let isToday = viewModel.isToday(date)
        return DayCarouselItemView(
            weekday: Self.weekdayLabel(for: date, abbreviated: isSelected),
            dayNumber: Self.dayNumber(for: date),
            state: dayState(isToday: isToday, isSelected: isSelected),
            action: { Task { await viewModel.selectDate(date) } },
            customAccessibilityLabel: Self.dayAccessibilityLabel(for: date, isToday: isToday, isSelected: isSelected)
        )
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : Self.unavailableDayOpacity)
        .accessibilityIdentifier("tasks.daily.day.\(Self.wireString(from: date))")
    }

    /// Only the adult carousel marks today (UX-009); Kids show the selected day alone (TEL-040).
    private func dayState(isToday: Bool, isSelected: Bool) -> DayCarouselState {
        let marksToday = viewModel.audience == .adult && isToday
        switch (marksToday, isSelected) {
        case (true, true): return .todaySelected
        case (true, false): return .today
        case (false, true): return .selected
        case (false, false): return .standard
        }
    }

    private static let unavailableDayOpacity = 0.35

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text("tasks.personal.dailyProgress")
                    .font(.app(.cardTitle))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer(minLength: 0)
                Text(progressValueText)
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.App.Background.cardHighlight)
                    Capsule().fill(Color.App.Action.primary)
                        .frame(width: geometry.size.width * progressFraction)
                }
            }
            .frame(height: Self.progressBarHeight)
            if viewModel.audience == .adult, (viewModel.progress?.total ?? 0) > 0 {
                Text("tasks.personal.encouragement")
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
            }
        }
        .padding(AppSpacing.xl)
        .appCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tasks.personal.dailyProgress"))
        .accessibilityValue(Text(progressAccessibilityText))
        .accessibilityIdentifier("tasks.daily.progress")
    }

    private static let progressBarHeight: CGFloat = 12

    private var progressValueText: String {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return String(localized: "tasks.personal.noTasks")
        }
        return String(
            format: String(localized: "tasks.personal.completedCountFormat"),
            progress.completed,
            progress.total
        )
    }

    private var progressFraction: Double {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return 0
        }
        return Double(progress.completed) / Double(progress.total)
    }

    private var progressAccessibilityText: String {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return String(localized: "tasks.personal.noTasks")
        }
        let percentage = Int((progress.percentage ?? 0).rounded())
        return String(
            format: String(localized: "tasks.personal.progressAccessibilityFormat"),
            progress.completed,
            progress.total,
            percentage
        )
    }

    // MARK: States

    /// Placeholder cards while the day loads (Figma 907:20405 adult, 907:27465 Kids).
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.base) {
            if viewModel.audience == .adult {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    skeletonBar(width: 150, height: 16)
                    skeletonBar(maxWidth: 320, height: 12)
                    skeletonBar(width: 110, height: 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.xl)
                .appCard()
                skeletonBar(width: 160, height: 22)
                    .padding(.top, AppSpacing.sm)
                ForEach(0 ..< 4, id: \.self) { _ in
                    HStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(Color.App.Background.cardHighlight)
                            .frame(width: Self.statusIconSize, height: Self.statusIconSize)
                        VStack(alignment: .leading, spacing: Self.skeletonLineSpacing) {
                            skeletonBar(width: 200, height: 14)
                            skeletonBar(width: 130, height: 12)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppSpacing.base)
                    .padding(.vertical, AppSpacing.base)
                    .appCard()
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    skeletonBar(width: 160, height: 16)
                    skeletonBar(maxWidth: .infinity, height: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.xl)
                .appCard()
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        skeletonBar(width: 200, height: 18)
                        skeletonBar(width: 120, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .appCard()
                }
            }
        }
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tasks.daily.loading"))
        .accessibilityIdentifier("tasks.daily.loading")
    }

    private static let skeletonLineSpacing: CGFloat = 6

    /// Fixed-width bars shrink on narrow screens instead of overflowing the card.
    private func skeletonBar(width: CGFloat? = nil, maxWidth: CGFloat? = nil, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.App.Background.cardHighlight)
            .frame(maxWidth: width ?? maxWidth, minHeight: height, maxHeight: height)
    }

    private var emptyState: some View {
        Group {
            if viewModel.audience == .adult {
                VStack(spacing: AppSpacing.sm) {
                    Text("tasks.personal.emptyDay")
                        .font(.app(.cardTitle))
                        .foregroundStyle(Color.App.Text.primary)
                    Text("tasks.personal.emptyHint")
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: onCreateTask) {
                        pillLabel("tasks.personal.newTask")
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.xs)
                    .accessibilityIdentifier("tasks.daily.empty_new")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.vertical, AppSpacing.giant)
                .appCard()
            } else {
                Text("tasks.personal.emptyDay")
                    .font(.app(.cardTitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.huge)
            }
        }
    }

    private var failureState: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.app(.title3))
                .foregroundStyle(Color.App.Text.highlight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("tasks.personal.loadError")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tasks.daily.load_error")
                    .accessibilityFocused($isErrorFocused)
                Button {
                    Task { await viewModel.load() }
                } label: {
                    pillLabel("tasks.error.retry")
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .appCard()
    }

    private var actionFailureBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Label(
                viewModel.actionFailure == .notCompleted
                    ? "task.complete.still_pending"
                    : "tasks.personal.actionError",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.app(.subtitle))
            .foregroundStyle(Color.App.Text.primary)
            Spacer(minLength: 0)
            Button("task.complete.refresh_status") {
                Task { await viewModel.refreshActionStatus() }
            }
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Text.highlight)
            .disabled(viewModel.actionFailureTaskID.map { viewModel.actionInFlight.contains($0) } ?? false)
            .accessibilityIdentifier("tasks.daily.action.refresh")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.banner)
                .fill(Color.App.Background.card)
        )
        .chalkStrokeBorder(RoundedRectangle(cornerRadius: AppRadius.banner), color: Color.App.Border.separator, lineWidth: 1)
        .accessibilityIdentifier("tasks.daily.action.error")
        .accessibilityFocused($isErrorFocused)
    }

    /// Primary pill action (Figma "Alta / Botões / Primário"): `appPrimaryPillSurface()` with a
    /// `Text.onAction` label.
    private func pillLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Text.onAction)
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.md)
            .appPrimaryPillSurface()
    }

    // MARK: List

    private var taskList: some View {
        LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
            if viewModel.audience == .adult {
                Text(sectionHeading)
                    .font(.app(.title2))
                    .foregroundStyle(Color.App.Text.primary)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityIdentifier("tasks.daily.section_heading")
            }
            ForEach(viewModel.items) { item in
                row(for: item)
            }
        }
    }

    private var sectionHeading: String {
        if viewModel.isToday(viewModel.selectedDate) {
            return String(format: String(localized: "tasks.personal.todaySectionFormat"), viewModel.items.count)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.setLocalizedDateFormatFromTemplate("d 'de' MMMM")
        return String(
            format: String(localized: "tasks.personal.dateSectionFormat"),
            formatter.string(from: viewModel.selectedDate),
            viewModel.items.count
        )
    }

    @ViewBuilder
    private func row(for item: OwnTaskListItem) -> some View {
        let isCompleted = item.displayStatus == .completed
        HStack(spacing: AppSpacing.xs) {
            if viewModel.showsToggle(item) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
                        viewModel.toggle(item)
                    }
                } label: {
                    statusIcon(for: item.displayStatus)
                        .frame(minWidth: Self.minTouchTarget, minHeight: Self.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canToggle(item))
                .accessibilityLabel(Text("\(item.task.status == .completed ? String(localized: "task.reopen.button") : String(localized: "task.complete.button")), \(item.task.title)"))
                .accessibilityIdentifier("tasks.daily.toggle.\(item.id.uuidString)")
            } else {
                statusIcon(for: item.displayStatus)
                    .frame(minWidth: Self.minTouchTarget, minHeight: Self.minTouchTarget)
                    .accessibilityHidden(true)
            }
            Button {
                onSelectTask(item.task.id)
            } label: {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(item.task.title)
                            .font(.app(viewModel.audience == .adult ? .cardTitle : .bodyStrong))
                            .strikethrough(isCompleted)
                            .foregroundStyle(isCompleted ? Color.App.Text.secondary : Color.App.Text.primary)
                        Text(detailText(for: item))
                            .font(.app(.subtitle))
                            .foregroundStyle(Color.App.Text.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.app(.noteStrong))
                        .foregroundStyle(Color.App.Text.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: Self.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel(for: item)))
            .accessibilityHint(Text("tasks.personal.openDetailHint"))
            .accessibilityIdentifier("tasks.daily.row.\(item.task.id.uuidString)")
            .accessibilityFocused($focusedTaskID, equals: item.id)
        }
        .padding(.leading, AppSpacing.sm)
        .padding(.trailing, AppSpacing.xl)
        .padding(.vertical, AppSpacing.sm)
        .appCard()
    }

    private static let minTouchTarget: CGFloat = 44
    private static let statusIconSize: CGFloat = 26

    @ViewBuilder
    private func statusIcon(for status: TaskStatus) -> some View {
        let (image, color): (Image, Color) = switch (viewModel.audience, status) {
        case (.adult, .completed): (Image(systemName: "checkmark.circle.fill"), Color.App.Text.primary)
        case (.adult, _): (Image(systemName: "circle"), Color.App.Text.secondary)
        case (_, .pending): (Image(systemName: "circle"), Color.App.Text.secondary)
        // Figma 907:27388 dashed clock, tinted as a template.
        case (_, .awaitingConfirmation): (Image("TaskStatusAwaiting").renderingMode(.template), Color.App.Text.secondary)
        case (_, .completed): (Image(systemName: "checkmark.circle.fill"), Color.App.Text.primary)
        }
        image
            .resizable()
            .scaledToFit()
            .frame(width: Self.statusIconSize, height: Self.statusIconSize)
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
    }

    private func detailText(for item: OwnTaskListItem) -> String {
        let statusText = String(localized: displayStatusLocalizationKey(for: item))
        guard viewModel.audience == .adult else {
            return statusText
        }
        return "\(assigneeSummary(for: item)) · \(weightLabel(item.task.weight))"
    }

    private func accessibilityLabel(for item: OwnTaskListItem) -> String {
        let statusText = String(localized: displayStatusLocalizationKey(for: item))
        guard viewModel.audience == .adult else {
            return "\(item.task.title), \(statusText)"
        }
        return "\(item.task.title), \(assigneeSummary(for: item)), \(weightLabel(item.task.weight)), \(statusText)"
    }

    private func assigneeSummary(for item: OwnTaskListItem) -> String {
        guard !item.task.assigneeIDs.isEmpty else {
            return String(localized: "tasks.personal.unassigned")
        }
        let orderedIDs = item.task.assigneeIDs.contains(currentMemberID)
            ? [currentMemberID] + item.task.assigneeIDs.filter { $0 != currentMemberID }
            : item.task.assigneeIDs
        let names = orderedIDs.map { id in
            if id == currentMemberID { return String(localized: "tasks.personal.you") }
            return viewModel.memberNames[id] ?? String(localized: "tasks.personal.otherMember")
        }
        return names.joined(separator: " \(String(localized: "tasks.personal.and")) ")
    }

    private func displayStatusLocalizationKey(for item: OwnTaskListItem) -> String.LocalizationValue {
        switch item.displayStatus {
        case .pending: "tasks.personal.status.pending"
        case .awaitingConfirmation: "tasks.personal.status.awaitingConfirmation"
        case .completed: "tasks.detail.status_completed"
        }
    }

    private func weightLabel(_ weight: EffortWeight) -> String {
        switch weight {
        case .low: String(localized: "tasks.personal.weightLow")
        case .medium: String(localized: "tasks.personal.weightMedium")
        case .high: String(localized: "tasks.personal.weightHigh")
        }
    }

    // MARK: Date formatting

    private static func dateSubtitle(for date: Date, isToday: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d 'de' MMMM")
        let raw = formatter.string(from: date)
        let base = String(raw.prefix(1)).uppercased(with: formatter.locale) + raw.dropFirst()
        guard isToday else { return base }
        return "\(base) · \(String(localized: "tasks.personal.today"))"
    }

    /// Figma 907:20352: the selected day shows "SEG", the others a single letter.
    private static func weekdayLabel(for date: Date, abbreviated: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = abbreviated ? "EEE" : "EEEEE"
        return formatter.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .uppercased(with: formatter.locale)
    }

    private static func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dayAccessibilityLabel(for date: Date, isToday: Bool, isSelected: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d 'de' MMMM")
        var label = formatter.string(from: date)
        if isToday {
            label += ", \(String(localized: "tasks.personal.today"))"
        }
        if isSelected {
            label += ", \(String(localized: "tasks.personal.selected"))"
        }
        return label
    }
}

