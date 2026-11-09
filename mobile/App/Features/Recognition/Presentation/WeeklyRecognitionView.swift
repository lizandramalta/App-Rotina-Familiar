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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("recognition.title")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    if viewModel.recognition != nil {
                        Text(viewModel.periodText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                content
            }
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isWhatsAppUnavailable {
                Label("recognition.whatsapp_unavailable", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityFocused($isNoticeFocused)
                    .accessibilityIdentifier("recognition.whatsapp_unavailable")
            }
            summaryCard(recognition)
            Text("recognition.invite")
                .font(.headline)
            TextField("recognition.message_placeholder", text: $viewModel.message, axis: .vertical)
                .lineLimit(3 ... 8)
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(Text("recognition.message_label"))
                .accessibilityHint(Text("recognition.message_hint"))
                .accessibilityIdentifier("recognition.message")
            actions
            if viewModel.showsCopyConfirmation {
                Label("recognition.copied", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("recognition.copied")
            }
        }
    }

    private func summaryCard(_ recognition: WeeklyRecognition) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .accessibilityHidden(true)
            Text(viewModel.headline)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            HStack(spacing: 32) {
                metric(value: recognition.points, label: "recognition.points")
                metric(value: recognition.completedTasks, label: "recognition.tasks")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.summaryAccessibilityLabel))
        .accessibilityIdentifier(recognition.isTie ? "recognition.summary.tie" : "recognition.summary.first")
    }

    private func metric(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if viewModel.showsWhatsAppAction {
                Button {
                    Task { await viewModel.shareOnWhatsApp() }
                } label: {
                    Label("recognition.share", systemImage: "message")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primary)
                .accessibilityHint(Text("recognition.share_hint"))
                .accessibilityIdentifier("recognition.share")
            }
            Button {
                viewModel.copyMessage()
            } label: {
                Label("recognition.copy", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(viewModel.showsWhatsAppAction ? AnyPrimitiveButtonStyle(.bordered) : AnyPrimitiveButtonStyle(.borderedProminent))
            .tint(Color.primary)
            .accessibilityIdentifier("recognition.copy")
        }
        .disabled(!viewModel.canShare)
    }

    private var loadingSkeleton: some View {
        // No provisional result: placeholders only (UX-020 §3 · Carregando).
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Circle().fill(Color(.systemFill)).frame(width: 56, height: 56)
                RoundedRectangle(cornerRadius: 6).fill(Color(.systemFill)).frame(height: 14)
                RoundedRectangle(cornerRadius: 6).fill(Color(.systemFill)).frame(width: 160, height: 14)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).frame(height: 88)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("recognition.loading"))
        .accessibilityIdentifier("recognition.loading")
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title)
                .accessibilityHidden(true)
            Text("recognition.error")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("recognition.retry")
                    .frame(minWidth: 160, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Color.primary)
            .accessibilityIdentifier("recognition.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recognition.error")
    }
}

/// Type-erases the two system button styles used by the copy action.
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<Style: PrimitiveButtonStyle>(_ style: Style) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
