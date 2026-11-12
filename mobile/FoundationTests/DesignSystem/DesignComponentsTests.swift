@testable import FamilyRoutine
import SwiftUI
import Testing
import UIKit

/// SCRUM-112 Phase 2 — core primitive components (Figma nodes 870:22509 / 960:25).
@MainActor
struct DesignComponentsTests {
    // MARK: StarDecorationView

    @Test("star variants map to the decoration tokens with distinct chalk seeds")
    func starVariants() {
        #expect(StarDecorationView.Variant.blue.fillColor == Color.App.Decoration.starBlue)
        #expect(StarDecorationView.Variant.yellow.fillColor == Color.App.Decoration.starYellow)
        #expect(StarDecorationView.Variant.blue.chalkSeed != StarDecorationView.Variant.yellow.chalkSeed)
        #expect(StarDecorationView.borderWidth == 2.5)
    }

    @Test("star shape follows the Figma outline inside the 58 pt frame")
    func starShapeGeometry() {
        let bounds = StarShape().path(in: CGRect(x: 0, y: 0, width: 58, height: 58)).boundingRect
        // Figma: star 49.5 pt wide, inset ~4 pt; the rounded tips trim the box slightly.
        #expect(abs(bounds.midX - 28.75) < 0.5)
        #expect(bounds.width > 34 && bounds.width < 37)
        #expect(bounds.minY > 9 && bounds.maxY < 46)
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
        #expect(CircularAddButton.borderWidth == 1.5)
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

    // MARK: ChalkStroke

    @Test("chalk config defaults match the Figma scatter brush f0.51_w0.06_aj180_sj0.4_sw1.5")
    func chalkConfigDefaults() {
        let config = ChalkStrokeConfig()
        #expect(config.gap == 0.51)
        #expect(config.wiggle == 0.06)
        #expect(config.angleJitter == .pi)
        #expect(config.scaleJitter == 0.4)
        #expect(config.lineWidth == 1.5)
        #expect(config.seed == 42)
        #expect(abs(config.maxPerpendicularOffset - 0.6) < 1e-9)
    }

    @Test("chalk scatter is deterministic per seed")
    func chalkDeterminism() {
        let path = Circle().path(in: CGRect(x: 0, y: 0, width: 44, height: 44))
        let first = ChalkScatter.particles(along: path, config: ChalkStrokeConfig())
        let second = ChalkScatter.particles(along: path, config: ChalkStrokeConfig())
        let otherSeed = ChalkScatter.particles(along: path, config: ChalkStrokeConfig(seed: 7))

        #expect(!first.isEmpty)
        #expect(first == second)
        #expect(first != otherSeed)
    }

    @Test("chalk particles are spaced by the gap and stay within the jitter bounds")
    func chalkParticleBounds() {
        let rect = CGRect(x: 0, y: 0, width: 44, height: 44)
        let config = ChalkStrokeConfig()
        let particles = ChalkScatter.particles(along: Circle().path(in: rect), config: config)
        let circumference = CGFloat.pi * 44

        #expect(abs(CGFloat(particles.count) - circumference / config.gap) <= 2)
        for particle in particles {
            let radius = hypot(particle.center.x - 22, particle.center.y - 22)
            #expect(abs(radius - 22) <= config.maxPerpendicularOffset + 0.05)
            #expect((1 - config.scaleJitter)...(1 + config.scaleJitter) ~= particle.scale)
            #expect(ChalkScatter.opacityRange ~= particle.opacity)
        }
    }

    @Test("chalk follows straight segments with the perpendicular wiggle only")
    func chalkStraightLine() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))
        let particles = ChalkScatter.particles(along: path, config: ChalkStrokeConfig(gap: 1))

        #expect(particles.count == 11)
        #expect(particles.map { $0.center.x.rounded() } == (0...10).map(CGFloat.init))
        #expect(particles.allSatisfy { abs($0.center.y) <= 0.6 })
    }

    @Test("seeded generator stays inside the requested range")
    func seededGeneratorRange() {
        var generator = SeededGenerator(seed: 1)
        let values = (0..<1000).map { _ in generator.next(in: -1...1) }
        #expect(values.allSatisfy { (-1...1) ~= $0 })
        #expect(Set(values).count > 990)
    }
}

@MainActor
private final class SelectionStore {
    var tab: AppTabItem?
}
