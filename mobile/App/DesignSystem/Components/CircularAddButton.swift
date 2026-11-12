import SwiftUI

/// Circular "add" button (Figma "Alta / Botões / Circular · Adicionar", node 907:13369).
/// The asset is the full Figma button: fill, hand-drawn chalk border and plus glyph.
struct CircularAddButton: View {
    static let diameter: CGFloat = 44
    static let assetName = "CircularAddButtonBackground"
    static let accessibilityTraits: AccessibilityTraits = .isButton
    static var accessibilityLabel: String { String(localized: "design_system.add_button.label") }

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(Self.assetName)
                .resizable()
                .frame(width: Self.diameter, height: Self.diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityLabel)
        .accessibilityAddTraits(Self.accessibilityTraits)
    }
}

#Preview {
    CircularAddButton {}
        .padding()
        .background(Color.App.Background.app)
}
