import SwiftUI

/// Visual state of a day in the day carousel (RN49).
enum DayCarouselState: CaseIterable {
    case standard
    case today
    case selected
    case todaySelected

    var isSelected: Bool { self == .selected || self == .todaySelected }

    var accessibilityTraits: AccessibilityTraits { isSelected ? [.isButton, .isSelected] : .isButton }

    var backgroundColor: Color {
        switch self {
        case .standard, .today: .clear
        case .selected: Color.App.System.dimming
        case .todaySelected: Color.App.Status.completed
        }
    }

    var weekdayColor: Color {
        isSelected ? Color.App.Text.onAction : Color.App.Text.secondary
    }

    var numberColor: Color {
        switch self {
        case .standard: Color.App.Text.primary
        case .today: Color.App.Status.completed
        case .selected, .todaySelected: Color.App.Text.onAction
        }
    }
}

/// One day in the day carousel (Figma "Alta / Controles / Dia do carrossel", node 907:13356).
struct DayCarouselItemView: View {
    static let size = CGSize(width: 46, height: 62)
    /// Figma "Alta · Texto/11 · Bold" — not part of the 14-role scale.
    static let weekdayFont = Font.system(size: 11, weight: .bold)
    /// Figma "Alta · Número/20" (Sour Gummy Medium) — 20 pt instead of the 22 pt `number` role.
    nonisolated static let numberTypography = AppTypography(
        size: 20, weight: .medium, design: .rounded, lineHeightMultiple: nil,
        fontName: AppTypography.sourGummyFontName
    )

    let weekday: String
    let dayNumber: String
    let state: DayCarouselState
    var action: (() -> Void)?

    var accessibilityLabel: String {
        String(localized: "design_system.day_carousel.label \(weekday) \(dayNumber)")
    }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: AppSpacing.xxs) {
                Text(weekday)
                    .font(Self.weekdayFont)
                    .foregroundStyle(state.weekdayColor)
                Text(dayNumber)
                    .font(.app(Self.numberTypography))
                    .foregroundStyle(state.numberColor)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(state.backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(state.accessibilityTraits)
    }
}

#Preview {
    HStack(spacing: AppSpacing.lg) {
        ForEach(DayCarouselState.allCases, id: \.self) { state in
            DayCarouselItemView(weekday: "SEG", dayNumber: "5", state: state)
        }
    }
    .padding()
    .background(Color.App.Background.app)
}
