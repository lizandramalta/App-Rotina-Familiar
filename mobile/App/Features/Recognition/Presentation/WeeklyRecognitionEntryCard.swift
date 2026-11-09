import SwiftUI

/// "Você é destaque da semana!" card of TEL-010/TEL-040 (Figma 578:184). Opens TEL-052.
struct WeeklyRecognitionEntryCard: View {
    let recognition: WeeklyRecognition
    let onOpen: (UUID) -> Void

    var body: some View {
        Button {
            onOpen(recognition.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("recognition.entry.title")
                        .font(.headline)
                    Text("recognition.entry.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("recognition.entry.hint"))
        .accessibilityIdentifier("recognition.entry")
    }
}
