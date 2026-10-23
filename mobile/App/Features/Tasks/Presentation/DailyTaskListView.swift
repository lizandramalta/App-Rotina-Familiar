import SwiftUI

/// TEL-010 (adult) and TEL-040 (Kids) — own daily checklist (SPEC-009 Fase 1, UX-009 §2/§3).
/// Never shows a Semana selector (CA-01). Row tap opens TEL-012 for adults only: UX-009 doesn't
/// define a Kids-side task detail destination, so Kids rows are informational, not navigable.
struct DailyTaskListView: View {
    @State private var viewModel: DailyTaskListViewModel
    let refreshRevision: Int
    let routineFeedback: Routine?
    let isRefreshingRoutine: Bool
    let routineRefreshFailed: Bool
    let onSelectTask: (UUID) -> Void
    let onCreateTask: () -> Void
    let onRefreshRoutine: () -> Void

    /// UX-009 §5: on period change, focus follows the updated header; on failure, it follows the
    /// error message and retry action. Same mechanism already used in EntryView.
    @AccessibilityFocusState private var isHeaderFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    init(
        audience: TaskAudience,
        repository: any TaskRepository,
        accessToken: String,
        refreshRevision: Int = 0,
        routineFeedback: Routine? = nil,
        isRefreshingRoutine: Bool = false,
        routineRefreshFailed: Bool = false,
        onSelectTask: @escaping (UUID) -> Void,
        onCreateTask: @escaping () -> Void,
        onRefreshRoutine: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: DailyTaskListViewModel(
            audience: audience,
            repository: repository,
            accessToken: accessToken
        ))
        self.refreshRevision = refreshRevision
        self.routineFeedback = routineFeedback
        self.isRefreshingRoutine = isRefreshingRoutine
        self.routineRefreshFailed = routineRefreshFailed
        self.onSelectTask = onSelectTask
        self.onCreateTask = onCreateTask
        self.onRefreshRoutine = onRefreshRoutine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let routineFeedback, viewModel.audience == .adult {
                    routineStatus(routineFeedback)
                }
                carousel
                Group {
                    if viewModel.isLoading, viewModel.items.isEmpty, viewModel.progress == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if viewModel.loadFailed, viewModel.items.isEmpty {
                        failureState
                    } else if viewModel.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            progressCard
                            if viewModel.loadFailed {
                                inlineFailureBanner
                            }
                            taskList
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .navigationTitle("destination.myTasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.audience == .adult {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateTask()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("tasks.personal.newTask"))
                    .accessibilityIdentifier("tasks.daily.new")
                }
            }
        }
        .task(id: refreshRevision) {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            isHeaderFocused = true
        }
        .onChange(of: viewModel.loadFailed) { _, failed in
            if failed {
                isErrorFocused = true
            }
        }
    }

    private func routineStatus(_ routine: Routine) -> some View {
        let statusKey: LocalizedStringKey = routine.materializationState == .pending
            ? "routines.materialization.preparing"
            : "routines.materialization.complete"
        return VStack(alignment: .leading, spacing: 8) {
            Label(statusKey, systemImage: routine.materializationState == .pending ? "clock" : "checkmark.circle")
            .accessibilityIdentifier("routines.list.status")
            if routineRefreshFailed {
                Text("routines.error_unavailable")
                    .font(.footnote)
            }
            if routine.materializationState == .pending || routineRefreshFailed {
                Button {
                    onRefreshRoutine()
                } label: {
                    if isRefreshingRoutine {
                        ProgressView()
                    } else {
                        Text("routines.materialization.refresh")
                    }
                }
                .disabled(isRefreshingRoutine)
                .accessibilityIdentifier("routines.list.refresh")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("destination.myTasks")
                .font(.largeTitle.bold())
            Text(Self.dateSubtitle(for: viewModel.selectedDate, isToday: viewModel.isToday(viewModel.selectedDate)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isHeaderFocused)
    }

    // MARK: Carousel (RN49)

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(carouselDates, id: \.self) { date in
                    dayButton(for: date)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var carouselDates: [Date] {
        let calendar = Calendar(identifier: .gregorian)
        return (-7 ... 6).compactMap { calendar.date(byAdding: .day, value: $0, to: viewModel.selectedDate) }
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
                Text(Self.dayNumber(for: date))
                    .font(.headline)
            }
            .frame(width: 44, height: 56)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.35)
        .accessibilityLabel(Text(Self.dayAccessibilityLabel(for: date, isToday: viewModel.isToday(date), isSelected: isSelected)))
        .accessibilityIdentifier("tasks.daily.day.\(Self.wireString(from: date))")
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("tasks.personal.dailyProgress")
                    .font(.headline)
                Spacer()
                Text(progressValueText)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progressFraction)
                .tint(.accentColor)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("tasks.personal.dailyProgress"))
        .accessibilityValue(Text(progressAccessibilityText))
    }

    private var progressValueText: String {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return "—"
        }
        return "\(progress.completed)/\(progress.total)"
    }

    private var progressFraction: Double {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return 0
        }
        return Double(progress.completed) / Double(progress.total)
    }

    private var progressAccessibilityText: String {
        guard let progress = viewModel.progress, progress.total > 0 else {
            return String(localized: "tasks.personal.emptyDay")
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
        VStack(spacing: 8) {
            Text("tasks.personal.emptyDay")
                .font(.headline)
            if viewModel.audience == .adult {
                Button {
                    onCreateTask()
                } label: {
                    Text("tasks.personal.newTask")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("tasks.personal.loadError", systemImage: "exclamationmark.triangle")
        } actions: {
            Button("tasks.error.retry") {
                Task { await viewModel.load() }
            }
        }
        .accessibilityIdentifier("tasks.daily.load_error")
        .accessibilityFocused($isErrorFocused)
    }

    private var inlineFailureBanner: some View {
        Label("tasks.personal.loadError", systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityIdentifier("tasks.daily.banner")
            .accessibilityFocused($isErrorFocused)
    }

    // MARK: List

    private var taskList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.items) { item in
                row(for: item)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func row(for item: OwnTaskListItem) -> some View {
        let isCompleted = item.displayStatus == .completed
        Button {
            if viewModel.audience == .adult {
                onSelectTask(item.task.id)
            }
        } label: {
            HStack(spacing: 12) {
                statusIcon(for: item.displayStatus)
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
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.audience == .kid)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel(for: item)))
        .accessibilityHint(viewModel.audience == .adult ? Text("tasks.personal.openDetailHint") : Text(""))
        .accessibilityIdentifier("tasks.daily.row.\(item.task.id.uuidString)")
    }

    private func statusIcon(for status: TaskStatus) -> some View {
        let (systemImage, color): (String, Color) = switch status {
        case .pending: ("circle", .secondary)
        case .awaitingConfirmation: ("clock", .orange)
        case .completed: ("checkmark.circle.fill", .green)
        }
        return Image(systemName: systemImage)
            .foregroundStyle(color)
            .font(.title3)
    }

    private func detailText(for item: OwnTaskListItem) -> String {
        let statusText = String(localized: displayStatusLocalizationKey(for: item))
        guard viewModel.audience == .adult else {
            return statusText
        }
        return "\(weightLabel(item.task.weight)) · \(statusText)"
    }

    private func accessibilityLabel(for item: OwnTaskListItem) -> String {
        let statusText = String(localized: displayStatusLocalizationKey(for: item))
        guard viewModel.audience == .adult else {
            return "\(item.task.title), \(statusText)"
        }
        return "\(item.task.title), \(weightLabel(item.task.weight)), \(statusText)"
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
        case .low: String(localized: "tasks.form.weight_option_low")
        case .medium: String(localized: "tasks.form.weight_option_medium")
        case .high: String(localized: "tasks.form.weight_option_high")
        }
    }

    // MARK: Date formatting

    private static func dateSubtitle(for date: Date, isToday: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d 'de' MMMM")
        let base = formatter.string(from: date)
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
