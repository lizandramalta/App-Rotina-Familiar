import SwiftUI

/// Hand-drawn chalk star sticker (Figma "Alta / Decoração / Estrela", nodes 926:21661 / 926:21662):
/// rounded star fill, procedural white chalk border and drop shadow.
/// Purely decorative: always hidden from assistive technologies.
struct StarDecorationView: View {
    enum Variant: CaseIterable {
        case blue
        case yellow

        var fillColor: Color {
            switch self {
            case .blue: Color.App.Decoration.starBlue
            case .yellow: Color.App.Decoration.starYellow
            }
        }

        /// Distinct seeds keep side-by-side stars from sharing the exact same grain.
        var chalkSeed: UInt64 {
            switch self {
            case .blue: 42
            case .yellow: 7
            }
        }
    }

    /// Decorations carry no information, so they never reach VoiceOver.
    static let isAccessibilityHidden = true
    static let borderWidth: CGFloat = 2.5

    let variant: Variant
    /// Side of the square frame; 58 pt is the Figma component frame (star + shadow margin).
    var size: CGFloat = 58

    var body: some View {
        StarShape()
            .fill(variant.fillColor)
            .chalkBorder(StarShape(), color: .white, lineWidth: Self.borderWidth, seed: variant.chalkSeed)
            .compositingGroup()
            .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
            .frame(width: size, height: size)
            .accessibilityHidden(Self.isAccessibilityHidden)
    }
}

/// Rounded five-pointed star traced from the Figma component (58 × 58 frame, star inset 4 pt),
/// normalized to the unit square so it scales with the frame.
nonisolated struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.4486, 0.2139))
        path.addCurve(to: point(0.5428, 0.2139), control1: point(0.4634, 0.1683), control2: point(0.5280, 0.1683))
        path.addLine(to: point(0.5804, 0.3296))
        path.addCurve(to: point(0.6275, 0.3638), control1: point(0.5870, 0.3500), control2: point(0.6060, 0.3638))
        path.addLine(to: point(0.7492, 0.3638))
        path.addCurve(to: point(0.7783, 0.4534), control1: point(0.7972, 0.3638), control2: point(0.8171, 0.4252))
        path.addLine(to: point(0.6798, 0.5249))
        path.addCurve(to: point(0.6618, 0.5803), control1: point(0.6625, 0.5375), control2: point(0.6552, 0.5599))
        path.addLine(to: point(0.6995, 0.6960))
        path.addCurve(to: point(0.6233, 0.7514), control1: point(0.7143, 0.7417), control2: point(0.6621, 0.7796))
        path.addLine(to: point(0.5248, 0.6798))
        path.addCurve(to: point(0.4666, 0.6798), control1: point(0.5074, 0.6672), control2: point(0.4840, 0.6672))
        path.addLine(to: point(0.3681, 0.7514))
        path.addCurve(to: point(0.2920, 0.6960), control1: point(0.3293, 0.7796), control2: point(0.2771, 0.7417))
        path.addLine(to: point(0.3296, 0.5803))
        path.addCurve(to: point(0.3116, 0.5249), control1: point(0.3362, 0.5599), control2: point(0.3289, 0.5375))
        path.addLine(to: point(0.2131, 0.4534))
        path.addCurve(to: point(0.2422, 0.3638), control1: point(0.1743, 0.4252), control2: point(0.1942, 0.3638))
        path.addLine(to: point(0.3639, 0.3638))
        path.addCurve(to: point(0.4110, 0.3296), control1: point(0.3854, 0.3638), control2: point(0.4044, 0.3500))
        path.addLine(to: point(0.4486, 0.2139))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: AppSpacing.lg) {
        StarDecorationView(variant: .blue)
        StarDecorationView(variant: .yellow)
        StarDecorationView(variant: .yellow, size: 28)
    }
    .padding()
    .background(Color.App.Background.app)
}
