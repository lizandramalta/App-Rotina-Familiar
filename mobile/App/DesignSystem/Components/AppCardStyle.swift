import SwiftUI

extension View {
    /// High-fidelity card surface (Figma TEL-010/TEL-012 cards): white card, 2 pt `Border.card`
    /// stroke and the soft Figma shadow 0 6 15 rgba(47, 60, 17, 0.07) — approximated with
    /// `Action.primary`, the closest token hue.
    func appCard(cornerRadius: CGFloat = AppRadius.cardBoard) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.App.Background.card)
                .shadow(color: Color.App.Action.primary.opacity(0.07), radius: 7.5, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.App.Border.card, lineWidth: 2)
        )
    }

    /// Primary green pill surface (Figma "Alta / Botões / Primário"): `Action.primarySoft` fill with
    /// the 2 pt `Action.primary` chalk border.
    func appPrimaryPillSurface() -> some View {
        background(Color.App.Action.primarySoft, in: Capsule())
            .appPrimaryPillBorder()
    }

    /// Chalk border of the primary pill, inset by half its width so it stays inside the frame
    /// (same approach as `CircularAddButton`).
    func appPrimaryPillBorder() -> some View {
        chalkBorder(
            Capsule().inset(by: AppPillButtonStyle.primaryBorderWidth / 2),
            color: Color.App.Action.primary,
            lineWidth: AppPillButtonStyle.primaryBorderWidth
        )
    }
}

/// Full-width capsule action (Figma "Alta / Botões"): `.primary` soft olive fill with olive chalk border, `.secondary` white with
/// separator stroke, `.highlight` soft green fill (MOD-006/MOD-011). Height 50 pt (adult) or 56 pt (Kids).
struct AppPillButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case highlight
    }

    static let height: CGFloat = 50
    /// SCRUM-125: on a `.highlight` pill (MOD-006, see MissionReopenConfirmationView), XCUITest
    /// measures the rendered frame at ~55.14pt instead of this nominal 56pt, deterministically
    /// (TaskReopenUITests.testSCRUM123MOD006ButtonsMeetMinimumTouchTargetForKids, SCRUM-118/123,
    /// asserts >=55 for that reason). Investigated down to `PillBody`'s `.frame(minHeight:)` →
    /// `.padding` → `.background(in: Capsule())` → `.overlay` (chalk stroke) → `.contentShape`
    /// chain and the chalk border's `Canvas` overlay (ChalkStroke.swift): none of those modifiers
    /// shrink the hosting view, and SwiftUI overlays never shrink their base view's frame.
    /// `MissionReopenConfirmationView` doesn't impose any external `.frame(height:)` either. This
    /// is almost certainly an XCUITest accessibility-frame measurement/rounding artifact, not a
    /// real SwiftUI layout bug — it's still comfortably above Apple's real 44pt accessibility
    /// floor. Do not "fix" this value without first reproducing a measured frame below 44pt; an
    /// arbitrary bump here wouldn't be generalizable across devices/simulators anyway.
    static let kidsHeight: CGFloat = 56
    static let primaryBorderWidth: CGFloat = 2

    var kind: Kind = .primary
    var height: CGFloat = Self.height
    /// Text color override (e.g. `System.destructive` for a destructive pill).
    var foreground: Color?
    var font: Font = .app(.bodyStrong)

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, style: self)
    }

    private struct PillBody: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration
        let style: AppPillButtonStyle

        var body: some View {
            configuration.label
                .font(style.font)
                .foregroundStyle(style.foreground ?? defaultForeground)
                .frame(maxWidth: .infinity, minHeight: style.height)
                .padding(.horizontal, AppSpacing.lg)
                .background(fill, in: Capsule())
                .overlay(stroke)
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
        }

        private var defaultForeground: Color {
            style.kind == .primary ? Color.App.Text.onAction : Color.App.Text.primary
        }

        private var fill: Color {
            switch style.kind {
            case .primary: Color.App.Action.primarySoft
            case .secondary: Color.App.Background.card
            case .highlight: Color.App.Background.cardHighlight
            }
        }

        @ViewBuilder
        private var stroke: some View {
            switch style.kind {
            case .primary: Color.clear.appPrimaryPillBorder()
            case .secondary: Capsule().strokeBorder(Color.App.Border.separator, lineWidth: 1.5)
            case .highlight: EmptyView()
            }
        }
    }
}
