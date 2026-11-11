@testable import FamilyRoutine
import SwiftUI
import Testing

/// SCRUM-112 Phase 2 — core primitive components (Figma nodes 870:22509 / 960:25).
@MainActor
struct DesignComponentsTests {
    // MARK: StarDecorationView

    @Test("star variants map to the decoration tokens")
    func starVariantColors() {
        #expect(StarDecorationView.Variant.blue.fillColor == Color.App.Decoration.starBlue)
        #expect(StarDecorationView.Variant.yellow.fillColor == Color.App.Decoration.starYellow)
    }

    @Test("star is hidden from assistive technologies")
    func starIsAccessibilityHidden() {
        #expect(StarDecorationView.isAccessibilityHidden)
    }

    @Test("star shape is a closed ten-vertex path inside its rect")
    func starShapeGeometry() {
        let rect = CGRect(x: 0, y: 0, width: 48, height: 48)
        let path = StarShape().path(in: rect)
        #expect(rect.insetBy(dx: -0.001, dy: -0.001).contains(path.boundingRect))
        #expect(path.boundingRect.minY == 0)
    }

    // MARK: CircularAddButton

    @Test("add button is a 44 pt button labeled with the localized \"Adicionar\"")
    func addButtonAccessibility() {
        #expect(CircularAddButton.accessibilityTraits.contains(.isButton))
        #expect(CircularAddButton.accessibilityLabel == "Adicionar")
        #expect(CircularAddButton.diameter == 44)
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
}
