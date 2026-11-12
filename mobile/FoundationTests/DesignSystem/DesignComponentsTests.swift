@testable import FamilyRoutine
import SwiftUI
import Testing
import UIKit

/// SCRUM-112 Phase 2 — core primitive components (Figma nodes 870:22509 / 960:25).
@MainActor
struct DesignComponentsTests {
    // MARK: StarDecorationView

    @Test("star variants map to bundled chalk sticker assets")
    func starVariantAssets() {
        #expect(StarDecorationView.Variant.blue.assetName == "StarDecorationBlue")
        #expect(StarDecorationView.Variant.yellow.assetName == "StarDecorationYellow")
        for variant in StarDecorationView.Variant.allCases {
            #expect(UIImage(named: variant.assetName) != nil, "missing asset \(variant.assetName)")
        }
    }

    @Test("star is hidden from assistive technologies")
    func starIsAccessibilityHidden() {
        #expect(StarDecorationView.isAccessibilityHidden)
    }

    // MARK: CircularAddButton

    @Test("add button is a 44 pt button labeled with the localized \"Adicionar\"")
    func addButtonAccessibility() {
        #expect(CircularAddButton.accessibilityTraits.contains(.isButton))
        #expect(CircularAddButton.accessibilityLabel == "Adicionar")
        #expect(CircularAddButton.diameter == 44)
        #expect(UIImage(named: CircularAddButton.assetName)?.size == CGSize(width: 44, height: 44))
    }

    // MARK: InlineFeedbackBanner

    @Test("banner keeps its message and defaults to the warning icon")
    func bannerContent() {
        let banner = InlineFeedbackBanner(message: "Falha ao salvar")
        #expect(banner.message == "Falha ao salvar")
        #expect(banner.systemImage == "exclamationmark.triangle")
        #expect(InlineFeedbackBanner(message: "x", systemImage: "info.circle").systemImage == "info.circle")
    }

    // MARK: DayCarouselItemView

    @Test("day state colors follow the Figma states")
    func dayStateColors() {
        #expect(DayCarouselState.standard.backgroundColor == .clear)
        #expect(DayCarouselState.standard.weekdayColor == Color.App.Text.secondary)
        #expect(DayCarouselState.standard.numberColor == Color.App.Text.primary)

        #expect(DayCarouselState.today.backgroundColor == .clear)
        #expect(DayCarouselState.today.weekdayColor == Color.App.Text.secondary)
        #expect(DayCarouselState.today.numberColor == Color.App.Status.completed)

        #expect(DayCarouselState.selected.backgroundColor == Color.App.System.dimming)
        #expect(DayCarouselState.selected.weekdayColor == Color.App.Text.onAction)
        #expect(DayCarouselState.selected.numberColor == Color.App.Text.onAction)

        #expect(DayCarouselState.todaySelected.backgroundColor == Color.App.Status.completed)
        #expect(DayCarouselState.todaySelected.weekdayColor == Color.App.Text.onAction)
        #expect(DayCarouselState.todaySelected.numberColor == Color.App.Text.onAction)
    }

    @Test("day item is a labeled button, selected only in selected states", arguments: DayCarouselState.allCases)
    func dayAccessibility(state: DayCarouselState) {
        let view = DayCarouselItemView(weekday: "SEG", dayNumber: "5", state: state)
        let expectSelected = state == .selected || state == .todaySelected

        #expect(view.accessibilityLabel == "SEG, dia 5")
        #expect(state.isSelected == expectSelected)
        #expect(state.accessibilityTraits.contains(.isButton))
        #expect(state.accessibilityTraits.contains(.isSelected) == expectSelected)
        #expect(DayCarouselItemView.size == CGSize(width: 46, height: 62))
    }

    // MARK: AppTabBar

    @Test("tab items keep the Figma order with localized titles")
    func tabItemsAndTitles() {
        #expect(AppTabItem.allCases == [.tasks, .family, .missions, .profile])
        #expect(AppTabItem.allCases.map(\.title) == ["Tarefas", "Família", "Missões", "Perfil"])
        #expect(AppTabItem.allCases.map(\.id) == AppTabItem.allCases)
    }

    @Test("tabs use the Figma vector icons: solid when active, outlined when inactive")
    func tabIcons() {
        #expect(AppTabItem.allCases.map { $0.iconAssetName(isSelected: true) }
            == ["TabBarTasksActive", "TabBarFamilyActive", "TabBarMissionsActive", "TabBarProfileActive"])
        #expect(AppTabItem.allCases.map { $0.iconAssetName(isSelected: false) }
            == ["TabBarTasksInactive", "TabBarFamilyInactive", "TabBarMissionsInactive", "TabBarProfileInactive"])
        for tab in AppTabItem.allCases {
            for isSelected in [true, false] {
                let image = UIImage(named: tab.iconAssetName(isSelected: isSelected))
                #expect(image?.size == CGSize(width: 24, height: 24), "\(tab) selected=\(isSelected)")
                #expect(image?.renderingMode != .alwaysTemplate)
            }
        }
    }

    @Test("active tab is highlighted and selected; inactive tab is a plain button")
    func tabAppearance() {
        let active = AppTabBar.ItemAppearance(isSelected: true)
        let inactive = AppTabBar.ItemAppearance(isSelected: false)

        #expect(active.backgroundColor == Color.App.Background.cardHighlight)
        #expect(inactive.backgroundColor == .clear)
        #expect(active.foregroundColor == Color.App.Text.primary)
        #expect(inactive.foregroundColor == Color.App.Text.primary)
        #expect(active.font == .system(size: 11, weight: .bold))
        #expect(inactive.font == .system(size: 11, weight: .regular))
        #expect(active.accessibilityTraits.contains(.isButton))
        #expect(active.accessibilityTraits.contains(.isSelected))
        #expect(inactive.accessibilityTraits.contains(.isButton))
        #expect(!inactive.accessibilityTraits.contains(.isSelected))
        #expect(AppTabBar.itemSize == CGSize(width: 88, height: 58))
    }

    @Test("selecting a tab writes through the binding", arguments: AppTabItem.allCases)
    func tabSelectionUpdatesBinding(tab: AppTabItem) {
        let store = SelectionStore()
        let tabBar = AppTabBar(selectedTab: Binding(get: { store.tab ?? .tasks }, set: { store.tab = $0 }))

        tabBar.select(tab)

        #expect(store.tab == tab)
    }
}

@MainActor
private final class SelectionStore {
    var tab: AppTabItem?
}
