import SwiftUI

/// Scatter-brush parameters of the Figma "Drone" chalk stroke
/// (node 907:13369, `data-figma-scatter="f0.51_w0.06_aj180_sj0.4_r0_s0_sw1.5"`).
nonisolated struct ChalkStrokeConfig: Equatable, Sendable {
    /// Distance between particles along the path, in points (`f`).
    var gap: CGFloat = 0.51
    /// Perpendicular wiggle (`w`); particles shift up to `wiggle × 10` pt (±0.6 pt) off the path.
    var wiggle: CGFloat = 0.06
    /// Maximum particle rotation either way, in radians (`aj` = 180°).
    var angleJitter: CGFloat = .pi
    /// Particle scale varies within `1 ± scaleJitter` (`sj`).
    var scaleJitter: CGFloat = 0.4
    /// Base particle size, in points (`sw`).
    var lineWidth: CGFloat = 1.5
    /// Seed of the deterministic generator; the same seed always yields the same texture.
    var seed: UInt64 = 42

    var maxPerpendicularOffset: CGFloat { wiggle * 10 }
}

/// One grain of chalk placed along the path.
nonisolated struct ChalkParticle: Equatable, Sendable {
    var center: CGPoint
    var rotation: CGFloat
    var scale: CGFloat
    var opacity: Double
}

/// Places chalk particles along a path. Pure and deterministic, so it is shared by rendering and tests.
nonisolated enum ChalkScatter {
    static let opacityRange: ClosedRange<Double> = 0.6...1.0

    static func particles(along path: Path, config: ChalkStrokeConfig) -> [ChalkParticle] {
        guard config.gap > 0 else { return [] }
        var random = SeededGenerator(seed: config.seed)
        var particles: [ChalkParticle] = []
        var distanceToNext: CGFloat = 0

        for (start, end) in segments(of: path) {
            let dx = end.x - start.x, dy = end.y - start.y
            let length = hypot(dx, dy)
            guard length > 0 else { continue }
            let tangent = CGPoint(x: dx / length, y: dy / length)
            let normal = CGPoint(x: -tangent.y, y: tangent.x)
            var distance = distanceToNext
            while distance <= length {
                let offset = random.next(in: -1...1) * config.maxPerpendicularOffset
                particles.append(ChalkParticle(
                    center: CGPoint(
                        x: start.x + tangent.x * distance + normal.x * offset,
                        y: start.y + tangent.y * distance + normal.y * offset
                    ),
                    rotation: atan2(tangent.y, tangent.x) + random.next(in: -1...1) * config.angleJitter,
                    scale: 1 + random.next(in: -1...1) * config.scaleJitter,
                    opacity: Double(random.next(in: CGFloat(opacityRange.lowerBound)...CGFloat(opacityRange.upperBound)))
                ))
                distance += config.gap
            }
            distanceToNext = distance - length
        }
        return particles
    }

    /// Flattens the path into straight segments (curves split into short chords).
    static func segments(of path: Path, curveSubdivisions: Int = 16) -> [(CGPoint, CGPoint)] {
        var segments: [(CGPoint, CGPoint)] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        func addCurve(_ point: (CGFloat) -> CGPoint) {
            for step in 1...curveSubdivisions {
                let next = point(CGFloat(step) / CGFloat(curveSubdivisions))
                segments.append((current, next))
                current = next
            }
        }

        path.forEach { element in
            switch element {
            case .move(let to):
                current = to
                subpathStart = to
            case .line(let to):
                segments.append((current, to))
                current = to
            case .quadCurve(let to, let control):
                let from = current
                addCurve { t in
                    let u = 1 - t
                    return CGPoint(
                        x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                        y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
                    )
                }
            case .curve(let to, let control1, let control2):
                let from = current
                addCurve { t in
                    let u = 1 - t
                    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                    return CGPoint(
                        x: a * from.x + b * control1.x + c * control2.x + d * to.x,
                        y: a * from.y + b * control1.y + c * control2.y + d * to.y
                    )
                }
            case .closeSubpath:
                if current != subpathStart { segments.append((current, subpathStart)) }
                current = subpathStart
            }
        }
        return segments
    }
}

/// 64-bit linear congruential generator (Knuth MMIX constants): fast, seedable and stable across runs,
/// so the chalk grain never flickers between frames.
nonisolated struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func nextUInt64() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    /// Uniform value in `range`, from the high 53 bits (the LCG's low bits are weak).
    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        let unit = CGFloat(nextUInt64() >> 11) / CGFloat(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

/// Procedural chalk stroke ("pincel Drone") traced along `shape`.
struct ChalkStroke<S: Shape>: View {
    let shape: S
    let color: Color
    var config = ChalkStrokeConfig()

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let path = shape.path(in: CGRect(origin: .zero, size: size))
            for particle in ChalkScatter.particles(along: path, config: config) {
                let width = config.lineWidth * particle.scale
                let grain = Path(ellipseIn: CGRect(x: -width / 2, y: -width * 0.35, width: width, height: width * 0.7))
                let transform = CGAffineTransform(translationX: particle.center.x, y: particle.center.y)
                    .rotated(by: particle.rotation)
                context.fill(grain.applying(transform), with: .color(color.opacity(particle.opacity)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Overlays a procedural chalk stroke traced along `shape`.
    func chalkBorder<S: Shape>(_ shape: S, color: Color, lineWidth: CGFloat = 1.5, seed: UInt64 = 42) -> some View {
        overlay(ChalkStroke(shape: shape, color: color, config: ChalkStrokeConfig(lineWidth: lineWidth, seed: seed)))
    }
}
