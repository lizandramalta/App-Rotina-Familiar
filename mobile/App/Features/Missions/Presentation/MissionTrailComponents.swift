import SwiftUI

// TEL-021 trail in high fidelity (Figma 907-14795, SPEC-016 CA-08, UX-016 §5.2 / UX-10 to UX-13).
// Presentation only: every value comes from the canonical mission detail (MA-07).

/// Visual kind of a trail node (UX-016 UX-11/UX-12). Color says completed / group / solo; the
/// icon says done / pending / awaiting, so awaiting confirmation never reads as completed.
nonisolated struct MissionTrailNodeAppearance: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        /// Blue with a check — any completed task.
        case completed
        /// Pink — two or more assignees, not completed.
        case group
        /// Green — zero or one assignee, not completed.
        case solo
    }

    enum Icon: Equatable, Sendable {
        case check
        case star
        case clock
    }

    let tone: Tone
    let icon: Icon

    init(tone: Tone, icon: Icon) {
        self.tone = tone
        self.icon = icon
    }

    init(task: MissionLinkedTask) {
        switch task.status {
        case .completed:
            tone = .completed
            icon = .check
        case .pending:
            tone = task.isGroupTask ? .group : .solo
            icon = .star
        case .awaitingConfirmation:
            tone = task.isGroupTask ? .group : .solo
            icon = .clock
        }
    }
}

/// Secondary line under a node title (UX-016 UX-10): pending shows "date · assignees"; completed
/// and awaiting show "state · assignees". Without assignees only the date/state remains.
nonisolated enum MissionTrailText {
    static func stateLabel(for status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "tasks.personal.status.pending")
        case .awaitingConfirmation: String(localized: "tasks.personal.status.awaitingConfirmation")
        case .completed: String(localized: "tasks.detail.status_completed")
        }
    }

    /// All names, joined with the locale's list format ("Isa e Theo", "Isa, Theo e Renata").
    static func assigneesText(_ assignees: [MissionTaskAssignee], locale: Locale = .current) -> String? {
        // A removed profile has no id; its label is localized here (the server sends the pt-BR text).
        let names = assignees
            .map { $0.memberID == nil ? String(localized: "missions.trail.removed_member") : $0.displayName }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        return names.formatted(.list(type: .and).locale(locale))
    }

    /// "Sáb, 10 out" from the `YYYY-MM-DD` wire date. The wire date is a calendar day in the family
    /// time zone, so it is parsed and read back in UTC to never shift by a day.
    static func shortDate(fromWire wire: String, locale: Locale = .current) -> String? {
        let parts = wire.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = locale
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return nil
        }
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        let monthIndex = calendar.component(.month, from: date) - 1
        let weekday = trimmedSymbol(calendar.shortStandaloneWeekdaySymbols[weekdayIndex], locale: locale)
        let month = trimmedSymbol(calendar.shortStandaloneMonthSymbols[monthIndex], locale: locale, capitalize: false)
        return String(
            format: String(localized: "missions.trail.task_date"),
            locale: locale,
            weekday,
            calendar.component(.day, from: date),
            month
        )
    }

    static func secondaryLine(for task: MissionLinkedTask, locale: Locale = .current) -> String {
        let names = assigneesText(task.assignees, locale: locale)
        let lead: String? = switch task.status {
        case .pending: task.scheduledDate.flatMap { shortDate(fromWire: $0, locale: locale) }
        case .awaitingConfirmation, .completed: stateLabel(for: task.status)
        }
        switch (lead, names) {
        case let (lead?, names?):
            return String(format: String(localized: "missions.trail.task_detail"), lead, names)
        case let (lead?, nil):
            return lead
        case let (nil, names?):
            return names
        case (nil, nil):
            return stateLabel(for: task.status)
        }
    }

    /// VoiceOver label of a node (UX-016 §8): title, state, date, assignees and the balloon.
    static func accessibilityLabel(for task: MissionLinkedTask, balloon: String?, locale: Locale = .current) -> String {
        var parts = [task.title, stateLabel(for: task.status)]
        if let date = task.scheduledDate.flatMap({ shortDate(fromWire: $0, locale: locale) }) {
            parts.append(date)
        }
        if let names = assigneesText(task.assignees, locale: locale) {
            parts.append(names)
        }
        if let balloon {
            parts.append(balloon)
        }
        return parts.joined(separator: ", ")
    }

    private static func trimmedSymbol(_ symbol: String, locale: Locale, capitalize: Bool = true) -> String {
        let trimmed = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard capitalize, let first = trimmed.first else { return trimmed }
        return String(first).uppercased(with: locale) + trimmed.dropFirst()
    }
}

/// 72 pt trail node with chalk outline (Figma "Nó · … · done / todo / mine").
struct MissionTrailNodeView: View {
    let appearance: MissionTrailNodeAppearance
    var size: CGFloat = 72

    private var fill: Color {
        switch appearance.tone {
        case .completed: Color.App.Status.completed
        case .group: Color.App.Status.waiting
        case .solo: Color.App.Background.subtle
        }
    }

    private var outline: Color {
        switch appearance.tone {
        case .completed: Color.App.Status.completedOutline
        case .group: Color.App.Status.waitingBorder
        case .solo: Color.App.Border.cardHighlight
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .chalkBorder(Circle().inset(by: 1.5), color: outline, lineWidth: 3, seed: seed)
                .shadow(color: Color.App.Action.primary.opacity(0.12), radius: 3, y: 3)
            icon
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var icon: some View {
        switch appearance.icon {
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.36, weight: .heavy))
                .foregroundStyle(Color.App.Text.onAction)
                .shadow(color: Color.App.Text.onCompleted.opacity(0.6), radius: 0, x: 1, y: 1.5)
        case .star:
            StarDecorationView(variant: appearance.tone == .group ? .blue : .yellow, size: size * 0.72)
        case .clock:
            Image(systemName: "clock.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(appearance.tone == .group ? Color.App.Status.waitingBorder : Color.App.Text.highlight)
        }
    }

    /// Distinct grain per tone so neighbouring nodes don't share the exact chalk pattern.
    private var seed: UInt64 {
        switch appearance.tone {
        case .completed: 11
        case .group: 23
        case .solo: 37
        }
    }
}

/// "SUA TAREFA" / "SUA VEZ!" balloon over the titular's node (UX-016 UX-04/UX-13).
struct MissionTrailBalloon: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.app(.captionStrong))
            .textCase(.uppercase)
            .foregroundStyle(Color.App.Text.primary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.App.Status.waiting, in: Capsule())
            .chalkBorder(Capsule().inset(by: 0.75), color: Color.App.Status.waitingBorder, lineWidth: 1.5, seed: 5)
            .accessibilityHidden(true)
    }
}

/// Dotted brush path between two node centers (Figma "Caminho · pontos (brush)"). Decorative.
struct MissionTrailDots: View {
    let fromX: CGFloat
    let toX: CGFloat
    var dotSize: CGFloat = 8
    var spacing: CGFloat = 15

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            // Inset from both ends so no dot hides under a node or gets clipped at the chest.
            let start = CGPoint(x: fromX, y: spacing * 0.6)
            let end = CGPoint(x: toX, y: max(size.height - spacing * 0.6, spacing * 0.6))
            let length = hypot(end.x - start.x, end.y - start.y)
            let count = max(Int(length / spacing), 1)
            for index in 0 ... count {
                let t = CGFloat(index) / CGFloat(count)
                // Slight bow so the path reads hand-drawn rather than ruled.
                let bow = sin(t * .pi) * 6
                let center = CGPoint(x: start.x + (end.x - start.x) * t + bow, y: start.y + (end.y - start.y) * t)
                let rect = CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: rect), with: .color(Color.App.Border.separator))
            }
        }
        .accessibilityHidden(true)
    }
}
