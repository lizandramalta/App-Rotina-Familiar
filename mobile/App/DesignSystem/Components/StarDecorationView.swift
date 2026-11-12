import SwiftUI

/// Hand-drawn chalk star sticker (Figma "Alta / Decoração / Estrela", nodes 926:21661 / 926:21662).
/// The asset already includes the rough white border and drop shadow.
/// Purely decorative: always hidden from assistive technologies.
struct StarDecorationView: View {
    enum Variant: CaseIterable {
        case blue
        case yellow

        var assetName: String {
            switch self {
            case .blue: "StarDecorationBlue"
            case .yellow: "StarDecorationYellow"
            }
        }
    }

    /// Decorations carry no information, so they never reach VoiceOver.
    static let isAccessibilityHidden = true

    let variant: Variant
    /// Side of the square frame the sticker fits in; 58 pt is the Figma component frame (star + shadow).
    var size: CGFloat = 58

    var body: some View {
        Image(variant.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(Self.isAccessibilityHidden)
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
