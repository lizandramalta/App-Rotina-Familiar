import SwiftUI

/// Circular "add" button (Figma "Alta / Botões / Circular · Adicionar", node 907:13369)
/// with the procedural chalk border.
struct CircularAddButton: View {
    static let diameter: CGFloat = 44
    static let borderWidth: CGFloat = 1.5
    static let accessibilityTraits: AccessibilityTraits = .isButton
    static var accessibilityLabel: String { String(localized: "design_system.add_button.label") }

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.App.Text.primary)
                .frame(width: Self.diameter, height: Self.diameter)
                .background(Circle().fill(Color.App.Background.app))
                // Inset by half the width so the chalk stays inside the 44 pt frame, like Figma's inside stroke.
                .chalkBorder(
                    Circle().inset(by: Self.borderWidth / 2),
                    color: Color.App.Border.separator,
                    lineWidth: Self.borderWidth
                )
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
