import SwiftUI
import UIKit

/// Typography scale from the high-fidelity design system.
/// Sour Gummy (number roles) is bundled; Source Serif 4 and Nunito are not yet, so those roles
/// use the matching system design (serif, default). A missing bundled font also falls back to the system design.
nonisolated struct AppTypography: Equatable, Sendable {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    /// Line height multiple from Figma (e.g. 1.15em); `nil` means the font default.
    let lineHeightMultiple: CGFloat?
    /// PostScript name of a bundled font; `nil` uses the system font with `design`.
    var fontName: String? = nil

    /// PostScript name of the bundled Sour Gummy variable font (default instance: Black).
    static let sourGummyFontName = "SourGummy-Black"

    var font: Font {
        if let uiFont { return Font(uiFont) }
        return .system(size: size, weight: weight, design: design)
    }

    /// The bundled font at `weight`, or `nil` when no font is set or it is not registered.
    var uiFont: UIFont? {
        guard let fontName, UIFont(name: fontName, size: size) != nil else { return nil }
        // Variable fonts default to their named instance; pin the `wght` axis to the token weight.
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(name: fontName, size: size)
            .addingAttributes([variation: [Self.weightAxisTag: Self.weightAxisValue(for: weight)]])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// OpenType `wght` axis tag as a four-char code.
    static let weightAxisTag = 0x7767_6874

    static func weightAxisValue(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight: 200
        case .thin: 100
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

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
    static let numberLarge = AppTypography(
        size: 44, weight: .medium, design: .rounded, lineHeightMultiple: nil, fontName: sourGummyFontName
    )
    static let number = AppTypography(
        size: 22, weight: .medium, design: .rounded, lineHeightMultiple: nil, fontName: sourGummyFontName
    )

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
