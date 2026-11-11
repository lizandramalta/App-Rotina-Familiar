import SwiftUI

/// Semantic color tokens from the high-fidelity design system (Figma "Alta · Cores").
/// Names are English translations of the Figma token names (e.g. `Texto/primario` → `Text.primary`).
nonisolated enum AppColor {
    nonisolated enum Background {
        static let app = Color(hex: 0xFBFCF8)
        static let card = Color(hex: 0xFFFFFF)
        static let cardHighlight = Color(hex: 0xE9EFDC)
        static let subtle = Color(hex: 0xE9EFDC)
        static let cardUpdate = Color(hex: 0xF2F6FC)
    }

    nonisolated enum Border {
        static let card = Color(hex: 0xCFE0BE)
        static let cardHighlight = Color(hex: 0xC3CCAD)
        static let separator = Color(hex: 0xDDE4CC)
    }

    nonisolated enum Text {
        static let primary = Color(hex: 0x423C1F)
        static let secondary = Color(hex: 0x6B6B6B)
        static let highlight = Color(hex: 0x57613D)
        static let onAction = Color(hex: 0xFFFFFF)
        static let onCompleted = Color(hex: 0x2E3F5C)
    }

    nonisolated enum Action {
        static let primary = Color(hex: 0x57613D)
        static let primarySoft = Color(hex: 0x81905B)
    }

    nonisolated enum Status {
        static let completed = Color(hex: 0x829DC4)
        static let completedBackground = Color(hex: 0xE3EBF7)
        static let completedBorder = Color(hex: 0xADBBD2)
        static let completedOutline = Color(hex: 0x5F7DAD)
        static let waiting = Color(hex: 0xEECDD9)
        static let waitingBackground = Color(hex: 0xFBEAF0)
        static let waitingBorder = Color(hex: 0xD4B3C0)
        static let pending = Color(hex: 0xF3ABA5)
    }

    nonisolated enum Member {
        static let renata = Color(hex: 0x9D659F)
        static let renataTrack = Color(hex: 0xE3D0EC)
        static let isa = Color(hex: 0xE27D74)
        static let isaTrack = Color(hex: 0xFFDDDD)
        static let theo = Color(hex: 0x317EAD)
        static let theoTrack = Color(hex: 0xC8D5DB)
        static let daniel = Color(hex: 0x8F8D42)
        static let danielTrack = Color(hex: 0xE0E0E0)
        static let you = Color(hex: 0x57613D)
        static let youTrack = Color(hex: 0xE9EFDC)
    }

    nonisolated enum Decoration {
        static let yellow = Color(hex: 0xFFF0B5)
        static let yellowShadow = Color(hex: 0xF3DC93)
        static let ochre = Color(hex: 0xC29A2E)
        static let ochreInner = Color(hex: 0xD9B24E)
        static let starBlue = Color(hex: 0xA9BBD8)
        static let starYellow = Color(hex: 0xE6CF86)
    }

    nonisolated enum System {
        static let destructive = Color(hex: 0xFF3B30)
        static let dimming = Color(hex: 0x000000)
    }
}

extension Color {
    /// Design system color tokens, e.g. `Color.App.Text.primary`.
    typealias App = AppColor

    /// Creates an opaque sRGB color from a `0xRRGGBB` literal.
    nonisolated init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
