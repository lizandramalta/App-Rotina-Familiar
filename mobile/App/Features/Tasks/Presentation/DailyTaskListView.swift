import SwiftUI

/// TEL-010 (adult) and TEL-040 (Kids) — own daily checklist (SPEC-009 Fase 1, UX-009 §2/§3).
/// Never shows a Semana selector (CA-01). Row tap opens TEL-012 for both audiences: SPEC-011
/// requires Kids to reach their own completed task to reopen it (TEL-012/MOD-006).
struct DailyTaskListView: View {
    @State private var viewModel: DailyTaskListViewModel
    @State private var visibleWeekStart: Date
    private let currentMemberID: UUID
    let refreshRevision: Int
    let onSelectTask: (UUID) -> Void
    let onCreateTask: () -> Void

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
        onCreateTask: @escaping () -> Void
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
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                carousel
                Group {
                    if viewModel.isLoading, viewModel.items.isEmpty, viewModel.progress == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if viewModel.loadFailed, viewModel.items.isEmpty {
                        failureState
                    } else if viewModel.isEmpty {
                        if viewModel.audience == .adult {
                            VStack(alignment: .leading, spacing: 20) {
                                progressCard
                                emptyState
                            }
                        } else {
                            emptyState
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
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
            .padding(.horizontal, viewModel.audience == .adult ? 20 : 16)
            .padding(.top, viewModel.audience == .adult ? 6 : 16)
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(viewModel.audience == .adult ? .hidden : .visible, for: .navigationBar)
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
            await viewModel.load()
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.audience == .adult ? "tasks.adult.title" : "destination.myTasks")
                    .font(.largeTitle.bold())
                Text(Self.dateSubtitle(
                    for: viewModel.selectedDate,
                    isToday: viewModel.audience == .kid && viewModel.isToday(viewModel.selectedDate)
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, viewModel.audience == .adult ? 2 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityFocused($isHeaderFocused)
            Spacer(minLength: 0)
            if viewModel.audience == .adult {
                Button(action: onCreateTask) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(Color(.systemBackground), in: Circle())
                .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                .accessibilityLabel(Text("tasks.personal.newTask"))
                .accessibilityIdentifier("tasks.daily.new")
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
        .frame(height: 56)
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
        return Button {
            Task { await viewModel.selectDate(date) }
        } label: {
            VStack(spacing: 4) {
                Text(Self.weekdayLetter(for: date))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color(.systemBackground) : Color.secondary)
                Text(Self.dayNumber(for: date))
                    .font(.headline)
                    .foregroundStyle(
                        isSelected ? Color(.systemBackground)
                            : (viewModel.audience == .adult && viewModel.isToday(date) ? Color.blue : Color.primary)
                    )
            }
            .frame(width: 46, height: 56)
            .background(
                isSelected
                    ? (viewModel.audience == .adult && viewModel.isToday(date) ? Color.blue : Color.primary)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.35)
        .accessibilityLabel(Text(Self.dayAccessibilityLabel(for: date, isToday: viewModel.isToday(date), isSelected: isSelected)))
        .accessibilityIdentifier("tasks.daily.day.\(Self.wireString(from: date))")
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: viewModel.audience == .adult ? 14 : 10) {
            HStack {
                Text("tasks.personal.dailyProgress")
                    .font(.headline)
                Spacer()
                Text(progressValueText)
                    .foregroundStyle(.secondary)
            }
            if viewModel.audience == .adult {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule().fill(Color.primary)
                            .frame(width: geometry.size.width * progressFraction)
                    }
                }
                .frame(height: 12)
            } else {
                ProgressView(value: progressFraction)
                    .tint(.primary)
            }
            if viewModel.audience == .adult, (viewModel.progress?.total ?? 0) > 0 {
                Text("tasks.personal.encouragement")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, viewModel.audience == .adult ? 20 : 16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tasks.personal.dailyProgress"))
        .accessibilityValue(Text(progressAccessibilityText))
        .accessibilityIdentifier("tasks.daily.progress")
    }

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

    private var emptyState: some View {
        Group {
            if viewModel.audience == .adult {
                VStack(spacing: 8) {
                    Text("tasks.personal.emptyDay")
                        .font(.headline)
                    Text("tasks.personal.emptyHint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("tasks.personal.newTask", action: onCreateTask)
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.primary, in: Capsule())
                        .accessibilityIdentifier("tasks.daily.empty_new")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            } else {
                Text("tasks.personal.emptyDay")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
    }

    private var failureState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text("tasks.personal.loadError")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tasks.daily.load_error")
                    .accessibilityFocused($isErrorFocused)
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Text("tasks.error.retry")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionFailureBanner: some View {
        HStack {
            Label(
                viewModel.actionFailure == .notCompleted
                    ? "task.complete.still_pending"
                    : "tasks.personal.actionError",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.footnote)
            Spacer()
            Button("task.complete.refresh_status") {
                Task { await viewModel.refreshActionStatus() }
            }
            .disabled(viewModel.actionFailureTaskID.map { viewModel.actionInFlight.contains($0) } ?? false)
            .accessibilityIdentifier("tasks.daily.action.refresh")
        }
        .foregroundStyle(.red)
        .accessibilityIdentifier("tasks.daily.action.error")
        .accessibilityFocused($isErrorFocused)
    }

    // MARK: List

    private var taskList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            if viewModel.audience == .adult {
                Text(sectionHeading)
                    .font(.title3.bold())
                    .padding(.bottom, 8)
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
        HStack(spacing: 0) {
            if viewModel.showsToggle(item) {
                Button {
                    viewModel.toggle(item)
                } label: {
                    statusIcon(for: item.displayStatus)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canToggle(item))
                .accessibilityLabel(Text("\(item.task.status == .completed ? String(localized: "task.reopen.button") : String(localized: "task.complete.button")), \(item.task.title)"))
                .accessibilityIdentifier("tasks.daily.toggle.\(item.id.uuidString)")
            } else {
                statusIcon(for: item.displayStatus)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHidden(true)
            }
            Button {
                onSelectTask(item.task.id)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.task.title)
                            .strikethrough(isCompleted)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                        Text(detailText(for: item))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.audience == .adult {
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel(for: item)))
            .accessibilityHint(Text("tasks.personal.openDetailHint"))
            .accessibilityIdentifier("tasks.daily.row.\(item.task.id.uuidString)")
            .accessibilityFocused($focusedTaskID, equals: item.id)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func statusIcon(for status: TaskStatus) -> some View {
        if viewModel.audience == .adult {
            if status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 26))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 26))
            }
        } else {
            let (systemImage, color): (String, Color) = switch status {
            case .pending: ("circle", .secondary)
            case .awaitingConfirmation: ("clock", .orange)
            case .completed: ("checkmark.circle.fill", .green)
            }
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .font(.title3)
        }
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

    private static func weekdayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
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
