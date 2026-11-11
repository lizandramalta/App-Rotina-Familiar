import SwiftUI

/// Inline feedback/error message (Figma "Alta / Feedback / Mensagem inline", node 907:13372).
/// `message` is expected to be already localized by the caller.
struct InlineFeedbackBanner: View {
    let message: String
    var systemImage: String = "exclamationmark.triangle"

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(message)
                .font(.app(.subtitle))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.App.Text.primary)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.banner)
                .fill(Color.App.Background.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.banner)
                .strokeBorder(Color.App.Border.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    InlineFeedbackBanner(message: "Não foi possível carregar as tarefas.")
        .padding()
        .background(Color.App.Background.app)
}
