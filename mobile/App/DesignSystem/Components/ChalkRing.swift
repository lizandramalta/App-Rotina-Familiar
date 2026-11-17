import SwiftUI

/// Geometry of a thick chalk ring: a band of `lineWidth` is filled with concentric thin chalk passes, so
/// rings, donut segments and dots keep the hand-drawn grain instead of a flat stroke (Figma "giz de cera").
nonisolated enum ChalkRing {
    /// Width of one chalk pass; passes overlap through their wiggle so the band reads as filled.
    static let passWidth: CGFloat = 1.8

    /// Radii of the passes that cover a band of `lineWidth` centred on `radius` (never below 0.5 pt).
    static func passRadii(radius: CGFloat, lineWidth: CGFloat) -> [CGFloat] {
        guard lineWidth > 0 else { return [] }
        let count = max(1, Int((lineWidth / passWidth).rounded(.up)))
        let step = lineWidth / CGFloat(count)
        return (0..<count)
            .map { radius - lineWidth / 2 + step * (CGFloat($0) + 0.5) }
            .filter { $0 >= 0.5 }
    }

    /// Clockwise arc from 12 o'clock, `from`/`to` as fractions of the full turn.
    static func arc(center: CGPoint, radius: CGFloat, from: Double, to: Double) -> Path {
        var path = Path()
        guard to > from else { return path }
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(-90 + from * 360), endAngle: .degrees(-90 + to * 360),
            clockwise: false
        )
        return path
    }

    static func config(seed: UInt64) -> ChalkStrokeConfig {
        // Wiggle of ±(passWidth / 2) makes neighbouring passes blend into one band.
        ChalkStrokeConfig(gap: 0.7, wiggle: passWidth / 20, lineWidth: passWidth * 1.35, seed: seed)
    }
}

/// Chalk arc (or full ring / dot) inscribed in its frame. Purely decorative.
struct ChalkRingArc: View {
    var from: Double = 0
    var to: Double = 1
    let color: Color
    let lineWidth: CGFloat
    var seed: UInt64 = 42

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let radius = min(size.width, size.height) / 2 - lineWidth / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for (index, passRadius) in ChalkRing.passRadii(radius: radius, lineWidth: lineWidth).enumerated() {
                let config = ChalkRing.config(seed: seed &+ UInt64(index) &* 31)
                let path = ChalkRing.arc(center: center, radius: passRadius, from: from, to: to)
                context.fillChalk(ChalkScatter.particles(along: path, config: config), color: color, lineWidth: config.lineWidth)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Thick hand-drawn chalk border: several inset chalk strokes along `shape` (e.g. the 4 pt TEL-050 board edge).
struct ChalkThickBorder<S: InsettableShape>: View {
    let shape: S
    let color: Color
    var width: CGFloat = 4
    var seed: UInt64 = 42

    var body: some View {
        let passes = max(1, Int((width / ChalkRing.passWidth).rounded(.up)))
        let step = width / CGFloat(passes)
        ZStack {
            ForEach(0..<passes, id: \.self) { index in
                ChalkStroke(
                    shape: shape.inset(by: step * (CGFloat(index) + 0.5)),
                    color: color,
                    config: ChalkRing.config(seed: seed &+ UInt64(index) &* 17)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
