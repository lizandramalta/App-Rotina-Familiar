import SwiftUI

/// "Você é destaque da semana!" card of TEL-010/TEL-040 (Figma 578:184). Opens TEL-052.
struct WeeklyRecognitionEntryCard: View {
    let recognition: WeeklyRecognition
    let onOpen: (UUID) -> Void

    private static let starSize: CGFloat = 44
    private static let minTouchTarget: CGFloat = 44

    var body: some View {
        Button {
            onOpen(recognition.id)
        } label: {
            HStack(spacing: AppSpacing.md) {
                StarDecorationView(variant: .yellow, size: Self.starSize)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("recognition.entry.title")
                        .font(.app(.cardTitle))
                        .foregroundStyle(Color.App.Text.primary)
                    Text("recognition.entry.subtitle")
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.app(.noteStrong))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: Self.minTouchTarget, alignment: .leading)
            .appCard()
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.cardBoard))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("recognition.entry.hint"))
        .accessibilityIdentifier("recognition.entry")
    }
}
