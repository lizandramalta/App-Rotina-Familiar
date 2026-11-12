import SwiftUI

/// Adult navigation destinations (Figma "Alta / Navegação / Tab bar · Adulto", node 870:22510).
enum AppTabItem: String, CaseIterable, Identifiable, Sendable {
    case tasks
    case family
    case missions
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .tasks: String(localized: "design_system.tab.tasks")
        case .family: String(localized: "design_system.tab.family")
        case .missions: String(localized: "design_system.tab.missions")
        case .profile: String(localized: "design_system.tab.profile")
        }
    }

    /// Figma vector icon: solid for the active tab, outlined otherwise.
    /// Rendered with original colors (the active Tasks icon has white checkmarks).
    func iconAssetName(isSelected: Bool) -> String {
        let base = switch self {
        case .tasks: "TabBarTasks"
        case .family: "TabBarFamily"
        case .missions: "TabBarMissions"
        case .profile: "TabBarProfile"
        }
        return base + (isSelected ? "Active" : "Inactive")
    }
}

/// Floating capsule tab bar. The capsule hugs its items (4 × 88 + padding = 360 pt);
/// the caller positions it on screen.
struct AppTabBar: View {
    static let itemSize = CGSize(width: 88, height: 58)
    static let itemCornerRadius: CGFloat = 29
    static let capsuleCornerRadius: CGFloat = 34

    /// Visual and accessibility attributes of one tab item.
    struct ItemAppearance: Equatable {
        let isSelected: Bool

        var backgroundColor: Color { isSelected ? Color.App.Background.cardHighlight : .clear }
        /// Figma uses `Text.primary` for both states; selection is shown by background, weight and fill.
        var foregroundColor: Color { Color.App.Text.primary }
        /// Figma "Alta · Texto/11 · Bold" / "Alta · Texto/11 · Regular".
        var font: Font { .system(size: 11, weight: isSelected ? .bold : .regular) }
        var accessibilityTraits: AccessibilityTraits { isSelected ? [.isButton, .isSelected] : .isButton }
    }

    @Binding var selectedTab: AppTabItem

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTabItem.allCases) { tab in
                item(for: tab)
            }
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Self.capsuleCornerRadius)
                .fill(Color.App.Background.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.capsuleCornerRadius)
                .strokeBorder(Color.App.Border.separator, lineWidth: 1.5)
        )
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
                    .frame(width: 24, height: 24)
                Text(tab.title)
                    .font(appearance.font)
            }
            .foregroundStyle(appearance.foregroundColor)
            .frame(width: Self.itemSize.width, height: Self.itemSize.height)
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
    AppTabBar(selectedTab: $selectedTab)
        .padding()
        .background(Color.App.Background.app)
}
