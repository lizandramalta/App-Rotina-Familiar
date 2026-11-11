import SwiftUI

/// Circular "add" button (Figma "Alta / Botões / Circular · Adicionar", node 907:13369).
struct CircularAddButton: View {
    static let diameter: CGFloat = 44
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
                .overlay(Circle().strokeBorder(Color.App.Border.separator, lineWidth: 1.5))
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
