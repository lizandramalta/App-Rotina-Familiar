import CoreGraphics
import CoreText
@testable import FamilyRoutine
import SwiftUI
import Testing
import UIKit

/// SCRUM-112 Phase 1 — design tokens foundation (Figma node 960:25).
@MainActor
struct DesignTokensTests {
    nonisolated static let colorTokens: [(name: String, color: Color, hex: UInt32)] = [
        ("Background.app", AppColor.Background.app, 0xFBFCF8),
        ("Background.card", AppColor.Background.card, 0xFFFFFF),
        ("Background.cardHighlight", AppColor.Background.cardHighlight, 0xE9EFDC),
        ("Background.subtle", AppColor.Background.subtle, 0xE9EFDC),
        ("Background.cardUpdate", AppColor.Background.cardUpdate, 0xF2F6FC),
        ("Border.card", AppColor.Border.card, 0xCFE0BE),
        ("Border.cardHighlight", AppColor.Border.cardHighlight, 0xC3CCAD),
        ("Border.separator", AppColor.Border.separator, 0xDDE4CC),
        ("Text.primary", AppColor.Text.primary, 0x423C1F),
        ("Text.secondary", AppColor.Text.secondary, 0x6B6B6B),
        ("Text.highlight", AppColor.Text.highlight, 0x57613D),
        ("Text.onAction", AppColor.Text.onAction, 0xFFFFFF),
        ("Text.onCompleted", AppColor.Text.onCompleted, 0x2E3F5C),
        ("Action.primary", AppColor.Action.primary, 0x57613D),
        ("Action.primarySoft", AppColor.Action.primarySoft, 0x81905B),
        ("Status.completed", AppColor.Status.completed, 0x829DC4),
        ("Status.completedBackground", AppColor.Status.completedBackground, 0xE3EBF7),
        ("Status.completedBorder", AppColor.Status.completedBorder, 0xADBBD2),
        ("Status.completedOutline", AppColor.Status.completedOutline, 0x5F7DAD),
        ("Status.waiting", AppColor.Status.waiting, 0xEECDD9),
        ("Status.waitingBackground", AppColor.Status.waitingBackground, 0xFBEAF0),
        ("Status.waitingBorder", AppColor.Status.waitingBorder, 0xD4B3C0),
        ("Status.pending", AppColor.Status.pending, 0xF3ABA5),
        ("Member.renata", AppColor.Member.renata, 0x9D659F),
        ("Member.renataTrack", AppColor.Member.renataTrack, 0xE3D0EC),
        ("Member.isa", AppColor.Member.isa, 0xE27D74),
        ("Member.isaTrack", AppColor.Member.isaTrack, 0xFFDDDD),
        ("Member.theo", AppColor.Member.theo, 0x317EAD),
        ("Member.theoTrack", AppColor.Member.theoTrack, 0xC8D5DB),
        ("Member.daniel", AppColor.Member.daniel, 0x8F8D42),
        ("Member.danielTrack", AppColor.Member.danielTrack, 0xE0E0E0),
        ("Member.you", AppColor.Member.you, 0x57613D),
        ("Member.youTrack", AppColor.Member.youTrack, 0xE9EFDC),
        ("Decoration.yellow", AppColor.Decoration.yellow, 0xFFF0B5),
        ("Decoration.yellowShadow", AppColor.Decoration.yellowShadow, 0xF3DC93),
        ("Decoration.ochre", AppColor.Decoration.ochre, 0xC29A2E),
        ("Decoration.ochreInner", AppColor.Decoration.ochreInner, 0xD9B24E),
        ("Decoration.starBlue", AppColor.Decoration.starBlue, 0xA9BBD8),
        ("Decoration.starYellow", AppColor.Decoration.starYellow, 0xE6CF86),
        ("System.destructive", AppColor.System.destructive, 0xFF3B30),
        ("System.dimming", AppColor.System.dimming, 0x000000),
    ]

    @Test("every color token resolves to its exact Figma hex", arguments: colorTokens)
    func colorTokenMatchesHex(token: (name: String, color: Color, hex: UInt32)) {
        let resolved = token.color.resolve(in: EnvironmentValues())
        let channel = { (value: Float) in UInt32((value * 255).rounded()) }
        let actual = channel(resolved.red) << 16 | channel(resolved.green) << 8 | channel(resolved.blue)

        #expect(actual == token.hex, "\(token.name): got \(String(format: "%06X", actual))")
        #expect(resolved.opacity == 1)
    }

    @Test("Color.App aliases the token namespace")
    func colorAppAlias() {
        #expect(Color.App.Text.primary == AppColor.Text.primary)
    }

    @Test("typography scale matches Figma sizes, weights and designs")
    func typographyScale() {
        let expected: [(AppTypography, CGFloat, Font.Weight, Font.Design, CGFloat?)] = [
            (.titleLarge, 34, .bold, .serif, 1.15),
            (.title1, 28, .bold, .serif, nil),
            (.title2, 22, .bold, .serif, nil),
            (.title3, 20, .bold, .serif, nil),
            (.cardTitle, 17, .bold, .serif, nil),
            (.body, 17, .medium, .default, 1.3),
            (.bodyStrong, 17, .bold, .default, nil),
            (.subtitle, 15, .medium, .default, nil),
            (.subtitleStrong, 15, .bold, .default, nil),
            (.note, 13, .regular, .default, nil),
            (.noteStrong, 13, .bold, .default, nil),
            (.caption, 12, .regular, .default, nil),
            (.numberLarge, 44, .medium, .rounded, nil),
            (.number, 22, .medium, .rounded, nil),
        ]

        #expect(AppTypography.allRoles.count == 14)
        #expect(AppTypography.allRoles == expected.map(\.0))
        for (role, size, weight, design, lineHeight) in expected {
            #expect(role.size == size)
            #expect(role.weight == weight)
            #expect(role.design == design)
            #expect(role.lineHeightMultiple == lineHeight)
            if role.fontName == nil {
                #expect(Font.app(role) == .system(size: size, weight: weight, design: design))
            }
        }
        #expect(AppTypography.allRoles.filter { $0.fontName != nil } == [.numberLarge, .number])
    }

    @Test("number roles render with the bundled Sour Gummy at the Figma weight",
          arguments: [AppTypography.numberLarge, .number, DayCarouselItemView.numberTypography])
    func sourGummyNumberRoles(role: AppTypography) throws {
        #expect(role.fontName == "SourGummy-Black")
        #expect(role.weight == .medium)

        let uiFont = try #require(role.uiFont, "SourGummy.ttf is not registered (UIAppFonts)")
        #expect(uiFont.familyName == "Sour Gummy")
        #expect(uiFont.pointSize == role.size)

        let variation = CTFontCopyVariation(uiFont as CTFont) as? [NSNumber: NSNumber]
        #expect(variation?[NSNumber(value: AppTypography.weightAxisTag)]?.doubleValue == 500)
    }

    @Test("unregistered font names fall back to the system design")
    func missingFontFallsBack() {
        let role = AppTypography(size: 22, weight: .medium, design: .rounded, lineHeightMultiple: nil, fontName: "Missing-Font")
        #expect(role.uiFont == nil)
        #expect(role.font == .system(size: 22, weight: .medium, design: .rounded))
    }

    @Test("spacing scale matches Figma values")
    func spacingScale() {
        let actual = [
            AppSpacing.xxs, AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.base,
            AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxxl, AppSpacing.giant,
            AppSpacing.huge, AppSpacing.massive, AppSpacing.colossal,
        ]
        #expect(actual == [2, 4, 8, 12, 14, 16, 18, 20, 24, 32, 40, 64, 80])
    }

    @Test("radius scale matches Figma values")
    func radiusScale() {
        let actual = [AppRadius.banner, AppRadius.card, AppRadius.sheet, AppRadius.pill, AppRadius.cardBoard]
        #expect(actual == [12, 14, 16, 22, 24])
    }
}
