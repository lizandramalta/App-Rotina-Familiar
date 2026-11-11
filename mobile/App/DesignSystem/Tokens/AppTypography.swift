import SwiftUI

/// Typography scale from the high-fidelity design system.
/// Figma fonts (Source Serif 4, Nunito, Sour Gummy) are not bundled yet, so each role
/// falls back to the matching system design (serif, default, rounded).
nonisolated struct AppTypography: Equatable, Sendable {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    /// Line height multiple from Figma (e.g. 1.15em); `nil` means the font default.
    let lineHeightMultiple: CGFloat?

    var font: Font { .system(size: size, weight: weight, design: design) }

    // Titles — Source Serif 4
    static let titleLarge = AppTypography(size: 34, weight: .bold, design: .serif, lineHeightMultiple: 1.15)
    static let title1 = AppTypography(size: 28, weight: .bold, design: .serif, lineHeightMultiple: nil)
    static let title2 = AppTypography(size: 22, weight: .bold, design: .serif, lineHeightMultiple: nil)
    static let title3 = AppTypography(size: 20, weight: .bold, design: .serif, lineHeightMultiple: nil)
    static let cardTitle = AppTypography(size: 17, weight: .bold, design: .serif, lineHeightMultiple: nil)

    // Text — Nunito
    static let body = AppTypography(size: 17, weight: .medium, design: .default, lineHeightMultiple: 1.3)
    static let bodyStrong = AppTypography(size: 17, weight: .bold, design: .default, lineHeightMultiple: nil)
    static let subtitle = AppTypography(size: 15, weight: .medium, design: .default, lineHeightMultiple: nil)
    static let subtitleStrong = AppTypography(size: 15, weight: .bold, design: .default, lineHeightMultiple: nil)
    static let note = AppTypography(size: 13, weight: .regular, design: .default, lineHeightMultiple: nil)
    static let noteStrong = AppTypography(size: 13, weight: .bold, design: .default, lineHeightMultiple: nil)
    static let caption = AppTypography(size: 12, weight: .regular, design: .default, lineHeightMultiple: nil)

    // Numbers — Sour Gummy
    static let numberLarge = AppTypography(size: 44, weight: .medium, design: .rounded, lineHeightMultiple: nil)
    static let number = AppTypography(size: 22, weight: .medium, design: .rounded, lineHeightMultiple: nil)

    static let allRoles: [AppTypography] = [
        .titleLarge, .title1, .title2, .title3, .cardTitle,
        .body, .bodyStrong, .subtitle, .subtitleStrong, .note, .noteStrong, .caption,
        .numberLarge, .number,
    ]
}

extension Font {
    /// Design system font, e.g. `.font(.app(.body))`.
    static func app(_ typography: AppTypography) -> Font { typography.font }
}
