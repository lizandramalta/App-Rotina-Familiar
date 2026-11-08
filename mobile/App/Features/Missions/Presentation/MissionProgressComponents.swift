import SwiftUI

// Shared building blocks for the gamified TEL-020/TEL-021 (Figma 579-59, SPEC-016 / UX-016).
// Everything rendered here derives from canonical server fields — no local recalculation (MA-07).

/// Full progress sentence ("1 de 4 tarefas concluídas (25%)") — always the VoiceOver label, even
/// where the screen only shows the compact "1 / 4" (decisão de 2026-11-08, UX-016 §7/§8).
func missionProgressAccessibilityText(completed: Int, total: Int, progressPercent: Double) -> String {
    String(
        format: String(localized: "mission.progress"),
        completed,
        total,
        displayedProgressPercent(progressPercent)
    )
}

/// Thick progress bar with the "x / y" count inside the filled part (Figma "Barra de progresso").
struct MissionProgressBar: View {
    let completedTaskCount: Int
    let taskCount: Int
    let progressPercent: Double
    var height: CGFloat = 20
    /// Track contrasts with the surface: gray on white cards, white on the gray detail banner.
    var trackColor: Color = Color(.systemGray5)

    private var fraction: Double {
        Double(displayedProgressPercent(progressPercent)) / 100
    }

    private var countText: String {
        String(format: String(localized: "mission.progress.short"), completedTaskCount, taskCount)
    }

    var body: some View {
        GeometryReader { proxy in
            let labelMinWidth: CGFloat = 52
            let fillWidth = max(proxy.size.width * fraction, labelMinWidth)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                // No filled segment at 0%, so an untouched mission never looks started.
                if fraction > 0 {
                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: min(fillWidth, proxy.size.width))
                }
                Text(countText)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(fraction > 0 ? Color(.systemBackground) : Color.secondary)
                    .padding(.leading, 12)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(missionProgressAccessibilityText(
            completed: completedTaskCount,
            total: taskCount,
            progressPercent: progressPercent
        )))
    }
}

/// Visual state of the chest (Figma: "Baú fechado · recompensa ao concluir", "Baú fechado · pronta
/// para resgate", "Baú aberto · recompensa escolhida"), derived from status + reward state.
enum MissionChestState: Equatable {
    case closed
    case ready
    case open

    init(status: MissionStatus, rewardState: MissionRewardState) {
        switch (status, rewardState) {
        case (_, .accepted): self = .open
        case (.completed, _): self = .ready
        case (.inProgress, _): self = .closed
        }
    }
}

/// Drawn chest illustration. Decorative: the state it conveys is always present as text nearby.
struct MissionChestView: View {
    let state: MissionChestState
    var size: CGFloat = 56

    var body: some View {
        let bodyHeight = size * 0.46
        let lidHeight = size * 0.26
        let width = size * 0.86
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(Color(.systemGray4))
                .overlay(RoundedRectangle(cornerRadius: size * 0.08).strokeBorder(Color.primary.opacity(0.75), lineWidth: 2))
                .frame(width: width, height: bodyHeight)
                .offset(y: size * 0.16)
            // Lid
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(state == .ready ? Color(.systemGray2) : Color(.systemGray5))
                .overlay(RoundedRectangle(cornerRadius: size * 0.1).strokeBorder(Color.primary.opacity(0.75), lineWidth: 2))
                .frame(width: width, height: lidHeight)
                .rotationEffect(.degrees(state == .open ? -18 : 0), anchor: .bottomLeading)
                .offset(y: state == .open ? -size * 0.2 : -size * 0.1)
            // Lock / reward
            if state == .open {
                Image(systemName: "plus.circle")
                    .font(.system(size: size * 0.26, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .offset(y: -size * 0.06)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: size * 0.14, height: size * 0.16)
                    .offset(y: size * 0.03)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Circle with the member's initial (Figma "Avatar · Sam"), used in "Quem já ajudou".
struct MissionMemberAvatar: View {
    let displayName: String
    var size: CGFloat = 32

    var body: some View {
        Text(displayName.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(Color(.systemGray5), in: Circle())
            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// Card with the "chunky" offset bottom edge used across Figma 579-59.
struct MissionCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var fill: Color = Color(.systemBackground)

    func body(content: Content) -> some View {
        // `.background` layers stack outward: the face first, then the offset edge behind it.
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color(.systemGray4), lineWidth: 1.5))
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray4))
                    .offset(y: 4)
            )
    }
}

extension View {
    func missionCard(cornerRadius: CGFloat = 20, fill: Color = Color(.systemBackground)) -> some View {
        modifier(MissionCardStyle(cornerRadius: cornerRadius, fill: fill))
    }
}

/// Reward situation text (SPEC-016 CA-05, UX-016 §5): only the canonical truth, never an action —
/// redemption belongs to UX-017 / SCRUM-90.
enum MissionRewardText {
    static func text(for state: MissionRewardState) -> String {
        switch state {
        case let .accepted(title):
            String(format: String(localized: "mission.reward.accepted"), title)
        case .redemptionAvailable:
            String(localized: "mission.reward.available")
        case .none:
            String(localized: "mission.reward.none")
        }
    }
}

// Plural-aware copy: `String(localized:defaultValue:)` keeps the interpolated arguments attached to
// the catalog key, so the pt-BR `one`/`other` variants resolve (`String(format:)` would drop them).

/// "N tarefas faltam" (Figma TEL-020 card footer), from canonical counts.
func missionTasksRemainingText(taskCount: Int, completedTaskCount: Int) -> String {
    let remaining = max(taskCount - completedTaskCount, 0)
    return String(localized: "mission.tasks_remaining", defaultValue: "\(remaining) tarefas faltam")
}

/// "N tarefas para abrir o baú" (Figma TEL-021 banner).
func missionBannerRemainingText(remaining: Int) -> String {
    String(localized: "mission.banner.remaining", defaultValue: "\(remaining) tarefas para abrir o baú")
}

/// "N em andamento · M concluídas" (Figma TEL-020 hero, adults).
func missionsHeroSummaryText(inProgress: Int, completed: Int) -> String {
    String(localized: "missions.hero.summary", defaultValue: "\(inProgress) em andamento · \(completed) concluídas")
}

/// "Vocês já concluíram M missões juntos!" (Figma TEL-020 hero, Kids).
func missionsHeroKidsSummaryText(completed: Int) -> String {
    String(localized: "missions.hero.kids_summary", defaultValue: "Vocês já concluíram \(completed) missões juntos!")
}

/// UX-016 §6 "Error não bloqueante": informs the failed refresh without hiding confirmed content.
struct MissionRefreshErrorBanner: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("mission.load.error")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("missions.common.retry", action: onRetry)
                .font(.subheadline.bold())
                .frame(minHeight: 44)
                .accessibilityIdentifier("missions.refresh_error.retry")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("missions.refresh_error.dismiss"))
        }
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("missions.refresh_error")
    }
}
