import Foundation

/// Local source of the draw (RN43/BA-15): the server never sees nor validates it. Replaceable in tests.
nonisolated protocol RewardDrawing: Sendable {
    /// An index in `0..<count`; `count` is always > 0.
    func drawIndex(count: Int) -> Int
}

nonisolated struct SystemRewardDrawing: RewardDrawing {
    func drawIndex(count: Int) -> Int {
        Int.random(in: 0 ..< count)
    }
}

/// Geometry of the wheel: equal slices clockwise from the top pointer.
nonisolated enum RewardWheelGeometry {
    static func sliceAngle(count: Int) -> Double {
        360.0 / Double(max(count, 1))
    }

    /// Absolute rotation (degrees) that brings the centre of `index` under the top pointer,
    /// after `fullTurns` extra turns past `current`.
    static func rotation(landingOn index: Int, count: Int, from current: Double, fullTurns: Int) -> Double {
        let slice = sliceAngle(count: count)
        let target = 360.0 - (Double(index) * slice + slice / 2)
        let normalizedCurrent = current.truncatingRemainder(dividingBy: 360)
        var delta = target - normalizedCurrent
        if delta < 0 { delta += 360 }
        return current + delta + Double(fullTurns) * 360
    }
}
