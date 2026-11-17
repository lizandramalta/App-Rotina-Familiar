import SwiftUI

/// Kids floating tab bar (Figma TEL-040 "Tab bar · Kids", node 907:27324): two items only —
/// Tarefas and Missões (no family or profile tab; Kids reach TEL-030 through the avatar).
struct KidsTabBar: View {
    nonisolated static let items: [AppTabItem] = [.tasks, .missions]
    static let itemWidth: CGFloat = 176
    static let iconSize: CGFloat = 26
    static let itemCornerRadius: CGFloat = 34
    static let capsuleCornerRadius: CGFloat = 40
    static let capsulePadding: CGFloat = 6

    /// Visual and accessibility attributes of one tab item.
    struct ItemAppearance: Equatable {
        let isSelected: Bool

        var backgroundColor: Color { isSelected ? Color.App.Background.cardHighlight : .clear }
        var foregroundColor: Color { Color.App.Text.primary }
        /// Figma "Alta · Texto/13 · Bold" for both states; selection is shown by background and icon fill.
        var font: Font { .app(.noteStrong) }
        var accessibilityTraits: AccessibilityTraits { isSelected ? [.isButton, .isSelected] : .isButton }
    }

    @Binding var selectedTab: AppTabItem

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.items) { tab in
                item(for: tab)
            }
        }
        .padding(Self.capsulePadding)
        .background(
            RoundedRectangle(cornerRadius: Self.capsuleCornerRadius)
                .fill(Color.App.Background.card)
        )
        .chalkStrokeBorder(RoundedRectangle(cornerRadius: Self.capsuleCornerRadius), color: Color.App.Border.separator, lineWidth: 1.5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.tab_bar")
    }

    func select(_ tab: AppTabItem) {
        selectedTab = tab
    }

    private func item(for tab: AppTabItem) -> some View {
        let isSelected = tab == selectedTab
        let appearance = ItemAppearance(isSelected: isSelected)
        return Button {
            select(tab)
        } label: {
            VStack(spacing: AppSpacing.xxs) {
                Image(tab.iconAssetName(isSelected: isSelected))
                    .resizable()
                    .frame(width: Self.iconSize, height: Self.iconSize)
                Text(tab.title)
                    .font(appearance.font)
            }
            .foregroundStyle(appearance.foregroundColor)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.base)
            // Flexible up to the Figma width so the capsule fits narrow screens inside the side gutters.
            .frame(maxWidth: Self.itemWidth)
            .background(
                RoundedRectangle(cornerRadius: Self.itemCornerRadius)
                    .fill(appearance.backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: Self.itemCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(appearance.accessibilityTraits)
    }
}

#Preview {
    @Previewable @State var selectedTab = AppTabItem.tasks
    KidsTabBar(selectedTab: $selectedTab)
        .padding()
        .background(Color.App.Background.app)
}
