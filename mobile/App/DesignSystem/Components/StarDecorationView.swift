import SwiftUI

/// Decorative five-pointed star (Figma "Alta / Decoração / Estrela", nodes 926:21661 / 926:21662).
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
    }

    /// Decorations carry no information, so they never reach VoiceOver.
    static let isAccessibilityHidden = true

    let variant: Variant
    var size: CGFloat = 48

    var body: some View {
        StarShape()
            .fill(variant.fillColor)
            .overlay(StarShape().stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
            .frame(width: size, height: size)
            .accessibilityHidden(Self.isAccessibilityHidden)
    }
}

/// Regular five-pointed star inscribed in the shape's rect, pointing up.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        // Inner/outer radius ratio of a regular pentagram.
        let innerRadius = outerRadius * 0.382
        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Double(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: AppSpacing.lg) {
        StarDecorationView(variant: .blue)
        StarDecorationView(variant: .yellow)
    }
    .padding()
    .background(Color.App.Background.app)
}
