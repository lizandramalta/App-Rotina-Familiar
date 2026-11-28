import SwiftUI
import UIKit

/// Liquid-glass circular header control (Figma "04 · Aba Família · Alta fidelidade", TEL-050 header):
/// 44 pt hit target, translucent white backing; `isActive` tints it with the primary soft fill.
struct FamilyCircleIconLabel: View {
    let systemImage: String
    var isActive = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isActive ? Color.App.Text.onAction : Color.App.Text.primary)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(isActive ? AnyShapeStyle(Color.App.Action.primarySoft) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(Circle().fill(Color.App.Background.card.opacity(isActive ? 0 : 0.6)))
                    .shadow(color: Color.App.Action.primary.opacity(0.12), radius: 6, y: 3)
            }
            // The filled (active) state has no outline.
            .chalkStrokeBorder(Circle(), color: isActive ? .clear : Color.App.Border.card, lineWidth: 1)
            .contentShape(Circle())
            .accessibilityHidden(true)
    }
}

/// Deterministic member palette built from the `Color.App.Member` tokens. The signed-in member always
/// uses "Você"; everyone else gets a stable color derived from the member ID (no ranking meaning).
nonisolated enum FamilyMemberPalette {
    struct Colors: Equatable {
        let tint: Color
        let track: Color
    }

    static let others: [Colors] = [
        Colors(tint: Color.App.Member.renata, track: Color.App.Member.renataTrack),
        Colors(tint: Color.App.Member.theo, track: Color.App.Member.theoTrack),
        Colors(tint: Color.App.Member.isa, track: Color.App.Member.isaTrack),
        Colors(tint: Color.App.Member.daniel, track: Color.App.Member.danielTrack),
    ]
    static let you = Colors(tint: Color.App.Member.you, track: Color.App.Member.youTrack)

    static func index(for memberID: UUID) -> Int {
        // `hashValue` is seeded per launch; the raw UUID bytes keep the color stable across launches.
        let bytes = withUnsafeBytes(of: memberID.uuid) { Array($0) }
        return bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF } % others.count
    }

    static func colors(for memberID: UUID, isCurrentMember: Bool) -> Colors {
        isCurrentMember ? you : others[index(for: memberID)]
    }
}

/// Member avatar. Family read models carry no photo yet, so it shows the initial on the member color.
struct MemberAvatarView: View {
    let name: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .serif))
            .foregroundStyle(Color.App.Text.onAction)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// TEL-050 member ring: 68 pt ring (4.5 pt stroke) around a 54 pt avatar, name and percentage below.
/// Members keep the order returned by the server (no ranking, SPEC-009).
struct MemberProgressRingView: View {
    let member: FamilyMemberProgress
    let colors: FamilyMemberPalette.Colors

    static let lineWidth: CGFloat = 4.5

    private var percentage: Int? { member.progress.percentage.map { Int($0.rounded()) } }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                // Track and progress are drawn in chalk (Figma "giz de cera"), not as flat strokes.
                ChalkRingArc(color: colors.track, lineWidth: Self.lineWidth, seed: 11)
                if let percentage, percentage > 0 {
                    ChalkRingArc(
                        to: Double(min(max(percentage, 0), 100)) / 100,
                        color: colors.tint, lineWidth: Self.lineWidth, seed: 23
                    )
                }
                MemberAvatarView(name: member.name, color: colors.tint, size: 54)
            }
            .frame(width: 68, height: 68)

            Text(member.name)
                .font(.app(.noteStrong))
                .foregroundStyle(Color.App.Text.primary)
                .lineLimit(1)
            Text(percentage.map { "\($0)%" } ?? String(localized: "family.overview.no_tasks_short"))
                .font(.app(.caption))
                .foregroundStyle(Color.App.Text.secondary)
                .lineLimit(1)
        }
        .frame(width: 78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percentage.map {
            String(format: String(localized: "family.overview.member_progress_accessibility"), member.name, $0)
        } ?? String(format: String(localized: "family.overview.no_tasks_accessibility"), member.name))
        .accessibilityHint("family.overview.member_open_hint")
    }
}

/// Chalk star chart attributing "Concluídas" to *who* completed it, not to a status mix (Figma
/// 879:13406): each contributing member's band is proportional to their share of the period's
/// total tasks, tinted with their ring color (`FamilyMemberPalette`) and stacked bottom-up in
/// server order; the uncompleted remainder fills the top in a neutral tone. Awaiting/Pendentes
/// stay as plain counts beside it — this view only ever visualizes completion.
struct MemberCompletionStarView: View {
    struct Band: Equatable {
        /// `nil` marks the neutral "not completed yet" band.
        let memberID: UUID?
        let fraction: Double
    }

    let members: [FamilyMemberProgress]
    let total: Int
    let colorFor: (UUID) -> Color
    /// ~150 pt measured off the Figma reference screenshot (879:13406); larger than the 58 pt
    /// decorative stars since this one carries the card's primary content, not a background accent.
    var size: CGFloat = 132

    /// Bands in top-to-bottom drawing order; the first server member ends up at the star's base.
    static func bands(members: [FamilyMemberProgress], total: Int) -> [Band] {
        guard total > 0 else { return [Band(memberID: nil, fraction: 1)] }
        let memberBands = members.compactMap { member -> Band? in
            guard member.progress.completed > 0 else { return nil }
            return Band(memberID: member.id, fraction: Double(member.progress.completed) / Double(total))
        }
        let remaining = 1 - memberBands.reduce(0) { $0 + $1.fraction }
        var ordered = Array(memberBands.reversed())
        if remaining > 0.0001 {
            ordered.insert(Band(memberID: nil, fraction: remaining), at: 0)
        }
        return ordered
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.bands(members: members, total: total).enumerated()), id: \.offset) { _, band in
                (band.memberID.map(colorFor) ?? Color.App.Border.cardHighlight)
                    .frame(height: size * band.fraction)
            }
        }
        .frame(width: size, height: size)
        .clipShape(StarShape())
        .chalkBorder(StarShape(), color: .white, lineWidth: StarDecorationView.borderWidth, seed: 61)
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
        .accessibilityHidden(true)
    }
}

/// Shared top bar of the Family filter sheets (Figma 879:13332 / 870:23454): close circle on the left,
/// "Filtros" centered, plain-text "Limpar" on the right.
struct FamilyFilterSheetTopBar: View {
    let clearIdentifier: String
    let isDefault: Bool
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                FamilyCircleIconLabel(systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("family.settings.hub.cancel")
            Spacer()
            Button("family.period.clear", action: onClear)
                .font(.app(.body))
                .foregroundStyle(isDefault ? Color.App.Text.disabled : Color.App.Text.primary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .disabled(isDefault)
                .accessibilityIdentifier(clearIdentifier)
        }
        .overlay {
            Text("family.period.filter_title")
                .font(.app(.cardTitle))
                .foregroundStyle(Color.App.Text.primary)
                .allowsHitTesting(false)
        }
    }
}

/// Início/Fim row: a dated capsule that expands a graphical calendar inline (RN49 bounds come from the caller).
struct FamilyDateCapsuleRow: View {
    let title: LocalizedStringKey
    let identifier: String
    @Binding var selection: Date
    let bounds: ClosedRange<Date>
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                    Spacer(minLength: AppSpacing.sm)
                    Text(selection, format: .dateTime.day().month(.abbreviated).year())
                        .font(.app(.subtitleStrong))
                        .foregroundStyle(isExpanded ? Color.App.Text.onAction : Color.App.Text.primary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs + AppSpacing.xxs)
                        .background(
                            isExpanded ? Color.App.Action.primarySoft : Color.App.Background.control,
                            in: Capsule()
                        )
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(selection, format: .dateTime.day().month(.wide).year()))
            .accessibilityIdentifier(identifier)

            if isExpanded {
                DatePicker(title, selection: $selection, in: bounds, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Color.App.Action.primary)
                    .padding(.bottom, AppSpacing.sm)
            }
        }
    }
}

/// Selectable pill (member and status chips): primary soft fill + 2 pt primary border when selected,
/// white with the card border otherwise.
struct FamilyChipModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(.app(isSelected ? .subtitleStrong : .subtitle))
            .foregroundStyle(isSelected ? Color.App.Text.onAction : Color.App.Text.primary)
            .frame(minHeight: 40)
            .background(isSelected ? Color.App.Action.primarySoft : Color.App.Background.card, in: Capsule())
            .chalkStrokeBorder(
                Capsule(),
                color: isSelected ? Color.App.Action.primary : Color.App.Border.card,
                lineWidth: isSelected ? 2 : 1.5
            )
            .contentShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

extension View {
    func familyChip(isSelected: Bool) -> some View { modifier(FamilyChipModifier(isSelected: isSelected)) }
}

/// Small section label above a Family card (e.g. "Convite", "Gestão", "Membros · 2").
struct FamilySectionLabel: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }
    init(verbatim value: String) { text = Text(value) }

    var body: some View {
        text
            .font(.app(.noteStrong))
            .foregroundStyle(Color.App.Text.secondary)
            .padding(.leading, AppSpacing.lg)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 1 pt separator inside a Family card, inset from the leading edge.
struct FamilyCardSeparator: View {
    var leadingInset: CGFloat = AppSpacing.lg

    var body: some View {
        Rectangle()
            .fill(Color.App.Border.separator)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

/// White notice card with a leading symbol (info, warning or error). Errors are announced as alerts.
struct FamilyNoticeCard: View {
    enum Tone { case info, warning, error }

    let message: Text
    var tone: Tone = .info

    init(_ key: LocalizedStringKey, tone: Tone = .info) {
        message = Text(key)
        self.tone = tone
    }

    /// For callers that need a formatted/interpolated message (e.g. a name), not a plain catalog key.
    init(_ text: Text, tone: Tone = .info) {
        message = text
        self.tone = tone
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tone == .info ? Color.App.Action.primary : Color.App.Text.primary)
                .accessibilityHidden(true)
            message
                .font(.app(.subtitle))
                .foregroundStyle(Color.App.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .appCard(cornerRadius: AppRadius.pill)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch tone {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

/// Task status glyph shared by TEL-011 and TEL-032. Status is also carried by the section/VoiceOver label
/// (RNF05). Pending uses the secondary text color: `Status.pending` on white is below the 3:1 contrast minimum.
struct FamilyTaskStatusIcon: View {
    let status: TaskStatus

    var body: some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .strokeBorder(Color.App.Text.secondary, lineWidth: 1.75)
                    .padding(2)
            case .awaitingConfirmation:
                Image("TaskStatusAwaiting")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.App.Text.secondary)
            case .completed:
                // Completion is #423C1F; blue is reserved for the family progress chart (SCRUM-126 Phase 9).
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundStyle(Color.App.Text.primary)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// "Editar nome Kids" sheet content shared by TEL-057 and TEL-032 (UX-003 §5.3): name only, Salvar and Cancelar.
/// Callers own the save/reconcile logic; this view owns layout, discard confirmation and dismissal locking.
struct FamilyKidsNameEditor: View {
    @Binding var name: String
    let fieldIdentifier: String
    let isInvalid: Bool
    let showsError: Bool
    let requiresRefresh: Bool
    let isSaving: Bool
    let hasChanges: Bool
    let onRetry: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void
    @State private var showsDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                FamilySectionLabel("family.member.manage.name")
                TextField("family.member.manage.name", text: $name)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                    .disabled(isSaving)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(minHeight: 52)
                    .appCard(cornerRadius: AppRadius.pill)
                    .accessibilityIdentifier(fieldIdentifier)
                if isInvalid {
                    FamilyNoticeCard("family.members.name.error_invalid", tone: .warning)
                }
                if showsError || requiresRefresh {
                    FamilyNoticeCard("family.member.manage.error", tone: .error)
                }
                if requiresRefresh {
                    Button("family.member.detail.retry", action: onRetry)
                        .buttonStyle(AppPillButtonStyle(kind: .secondary))
                }
            }
            .padding(AppSpacing.xxl)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("family.settings.hub.edit_kids_name")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("family.settings.hub.cancel") {
                    if hasChanges { showsDiscard = true } else { onClose() }
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("family.settings.hub.save", action: onSave)
                    .fontWeight(.bold)
                    .disabled(isSaving || requiresRefresh || !hasChanges)
            }
        }
        .tint(Color.App.Action.primary)
        .confirmationDialog("family.members.discard.title", isPresented: $showsDiscard) {
            Button("family.members.discard.confirm", role: .destructive, action: onClose)
            Button("family.members.discard.keep_editing", role: .cancel) {}
        } message: {
            Text("family.members.discard.message")
        }
        .interactiveDismissDisabled(isSaving || hasChanges)
    }
}

/// Left-aligned wrapping row layout (status chips in the TEL-011 filter, Figma 870:23478): every chip stays
/// visible and wraps to a new line instead of scrolling.
struct FamilyFlowLayout: Layout {
    var spacing: CGFloat = AppSpacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = Self.rows(sizes: subviews.map { $0.sizeThatFits(.unspecified) }, maxWidth: proposal.width ?? .infinity, spacing: spacing)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for row in Self.rows(sizes: sizes, maxWidth: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for index in row.indices {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += row.height + spacing
        }
    }

    struct Row: Equatable {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    /// Greedy line breaking; pure so it can be unit-tested.
    static func rows(sizes: [CGSize], maxWidth: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row(indices: [], width: 0, height: 0)
        for (index, size) in sizes.enumerated() {
            let proposed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && proposed > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = proposed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Styles ONE segmented picker (TEL-032 Dia/Semana, Figma 870:24322) without touching the global
/// `UISegmentedControl.appearance()`: it finds the control by its accessibility identifier in the window and sets
/// the light green track, white selected segment and #423C1F labels on that instance only. If the control is not
/// found, nothing changes (the system style remains).
struct SegmentedControlStyler: UIViewRepresentable {
    let identifier: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async { [identifier] in
            guard let window = view.window,
                  let control = Self.findControl(in: window, identifier: identifier) else { return }
            Self.apply(to: control)
        }
    }

    static func findControl(in root: UIView, identifier: String) -> UISegmentedControl? {
        if let control = root as? UISegmentedControl, control.accessibilityIdentifier == identifier { return control }
        for subview in root.subviews {
            if let found = findControl(in: subview, identifier: identifier) { return found }
        }
        return nil
    }

    static func apply(to control: UISegmentedControl) {
        let text = UIColor(Color.App.Text.primary)
        control.backgroundColor = UIColor(Color.App.Background.cardHighlight)
        control.selectedSegmentTintColor = UIColor(Color.App.Background.card)
        control.setTitleTextAttributes([.foregroundColor: text], for: .normal)
        control.setTitleTextAttributes(
            [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 15, weight: .bold)], for: .selected
        )
    }
}
