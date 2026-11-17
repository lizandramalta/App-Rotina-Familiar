import SwiftUI

/// TEL-052 — Meu destaque semanal (SPEC-020 CA-07/CA-08, UX-020). Pushed from the entry card in
/// TEL-010/TEL-040 or from the notification; tab bar stays hidden like every pushed screen.
/// Kids see the same result and actions, with no family load or PDF (UX-CA-04).
struct WeeklyRecognitionView: View {
    @State private var viewModel: WeeklyRecognitionViewModel
    @AccessibilityFocusState private var isNoticeFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: WeeklyRecognitionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private static let maxContentWidth: CGFloat = 600
    private static let summaryStarSize: CGFloat = 64
    private static let skeletonLineHeight: CGFloat = 14
    private static let skeletonShortLineWidth: CGFloat = 160
    private static let skeletonMessageHeight: CGFloat = 88
    private static let retryMaxWidth: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("recognition.title")
                        .font(.app(.title1))
                        .foregroundStyle(Color.App.Text.primary)
                        .accessibilityAddTraits(.isHeader)
                    if viewModel.recognition != nil {
                        Text(viewModel.periodText)
                            .font(.app(.subtitle))
                            .foregroundStyle(Color.App.Text.secondary)
                            .accessibilityHidden(true)
                    }
                }
                content
            }
            .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .hidesAppTabBar()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recognition.screen")
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from WhatsApp (sent or cancelled) only revalidates; it never claims a send.
            if phase == .active, viewModel.recognition != nil { Task { await viewModel.load() } }
        }
        .onChange(of: viewModel.isWhatsAppUnavailable) { _, unavailable in
            if unavailable { isNoticeFocused = true }
        }
        .onChange(of: viewModel.copyConfirmationRevision) { _, _ in
            AccessibilityNotification.Announcement(String(localized: "recognition.copied")).post()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingSkeleton
        case .error, .sessionExpired:
            errorState
        case let .loaded(recognition):
            loaded(recognition)
        }
    }

    private func loaded(_ recognition: WeeklyRecognition) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if viewModel.isWhatsAppUnavailable {
                Label("recognition.whatsapp_unavailable", systemImage: "exclamationmark.circle.fill")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .padding(AppSpacing.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard(cornerRadius: AppRadius.card)
                    .accessibilityFocused($isNoticeFocused)
                    .accessibilityIdentifier("recognition.whatsapp_unavailable")
            }
            summaryCard(recognition)
            Text("recognition.invite")
                .font(.app(.bodyStrong))
                .foregroundStyle(Color.App.Text.primary)
            TextField("recognition.message_placeholder", text: $viewModel.message, axis: .vertical)
                .lineLimit(3 ... 8)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.primary)
                .padding(AppSpacing.base)
                .appCard(cornerRadius: AppRadius.card)
                .accessibilityLabel(Text("recognition.message_label"))
                .accessibilityHint(Text("recognition.message_hint"))
                .accessibilityIdentifier("recognition.message")
            actions
            if viewModel.showsCopyConfirmation {
                Label("recognition.copied", systemImage: "checkmark.circle")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .accessibilityIdentifier("recognition.copied")
            }
        }
    }

    private func summaryCard(_ recognition: WeeklyRecognition) -> some View {
        VStack(spacing: AppSpacing.md) {
            StarDecorationView(variant: .yellow, size: Self.summaryStarSize)
            Text(viewModel.headline)
                .font(.app(.title2))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.giant) {
                metric(value: recognition.points, label: "recognition.points")
                metric(value: recognition.completedTasks, label: "recognition.tasks")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
        .appCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.summaryAccessibilityLabel))
        .accessibilityIdentifier(recognition.isTie ? "recognition.summary.tie" : "recognition.summary.first")
    }

    private func metric(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(value, format: .number)
                .font(.app(.numberMedium))
                .foregroundStyle(Color.App.Text.primary)
            Text(label)
                .font(.app(.caption))
                .foregroundStyle(Color.App.Text.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.md) {
            if viewModel.showsWhatsAppAction {
                Button {
                    Task { await viewModel.shareOnWhatsApp() }
                } label: {
                    Label("recognition.share", systemImage: "message")
                }
                .buttonStyle(AppPillButtonStyle(kind: .primary))
                .accessibilityHint(Text("recognition.share_hint"))
                .accessibilityIdentifier("recognition.share")
            }
            // Copy is secondary next to WhatsApp and becomes the primary action without it.
            Button {
                viewModel.copyMessage()
            } label: {
                Label("recognition.copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(AppPillButtonStyle(kind: viewModel.showsWhatsAppAction ? .secondary : .primary))
            .accessibilityIdentifier("recognition.copy")
        }
        .disabled(!viewModel.canShare)
    }

    private var loadingSkeleton: some View {
        // No provisional result: placeholders only (UX-020 §3 · Carregando).
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                Circle()
                    .fill(Color.App.Background.cardHighlight)
                    .frame(width: Self.summaryStarSize, height: Self.summaryStarSize)
                Capsule()
                    .fill(Color.App.Background.cardHighlight)
                    .frame(height: Self.skeletonLineHeight)
                Capsule()
                    .fill(Color.App.Background.cardHighlight)
                    .frame(width: Self.skeletonShortLineWidth, height: Self.skeletonLineHeight)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.xxl)
            .appCard()
            Color.clear
                .frame(height: Self.skeletonMessageHeight)
                .appCard(cornerRadius: AppRadius.card)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("recognition.loading"))
        .accessibilityIdentifier("recognition.loading")
    }

    private var errorState: some View {
        VStack(spacing: AppSpacing.base) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.app(.title1))
                .foregroundStyle(Color.App.Text.secondary)
                .accessibilityHidden(true)
            Text("recognition.error")
                .font(.app(.title2))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("recognition.retry")
            }
            .buttonStyle(AppPillButtonStyle(kind: .secondary))
            .frame(maxWidth: Self.retryMaxWidth)
            .accessibilityIdentifier("recognition.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.giant)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recognition.error")
    }
}
