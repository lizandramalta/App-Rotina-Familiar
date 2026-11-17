import SwiftUI

/// TEL-016 — inspect a current Kids signal and explicitly confirm or reject it (UX-013 §5.2; Figma 870:27114).
struct KidsSignalDetailView: View {
    private enum Attempt { case load, decision }

    @State private var viewModel: KidsSignalDetailViewModel
    @State private var lastAttempt: Attempt = .load
    @State private var showsPhotoViewer = false
    let onResolved: () -> Void
    /// Embedded as the iPad split detail: no own navigation title and no pop on resolve (the queue reselects).
    let isEmbedded: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(viewModel: KidsSignalDetailViewModel, isEmbedded: Bool = false, onResolved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.isEmbedded = isEmbedded
        self.onResolved = onResolved
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbedded { backBar }
            content
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.App.Background.app.ignoresSafeArea())
            .modifier(DetailNavigationTitle(isEmbedded: isEmbedded))
            .hidesAppTabBar()
            .task { await load() }
            .onChange(of: viewModel.resolved) { _, resolved in
                // Success, including a late `applied: false`, returns to the refreshed queue silently (UX-013 §5.2).
                guard resolved else { return }
                onResolved()
                if !isEmbedded { dismiss() }
            }
            .onChange(of: viewModel.isUnavailable) { _, unavailable in
                if unavailable { onResolved() }
            }
            .sheet(isPresented: $showsPhotoViewer) {
                if let photo = viewModel.photo, let image = UIImage(data: photo), let detail = viewModel.detail {
                    KidsPrivatePhotoViewer(image: image, caption: Self.photoCaption(detail))
                }
            }
    }

    /// "<tarefa> · <criança> · <data e hora>" under the enlarged photo (Figma 870:27317).
    static func photoCaption(_ detail: KidsSignalDetail) -> String {
        "\(detail.taskTitle) · \(detail.childName) · \(detail.signaledAt.formatted(date: .abbreviated, time: .shortened))"
    }

    /// Circular back button replacing the navigation bar (Figma 870:27124); available in every state.
    private var backBar: some View {
        HStack {
            Button { dismiss() } label: {
                FamilyCircleIconLabel(systemImage: "chevron.backward")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("family.tasks.back")
            .accessibilityIdentifier("kidsReview.detail.back")
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if let detail = viewModel.detail {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    if viewModel.failed {
                        FamilyNoticeCard(
                            lastAttempt == .decision ? "kidsReview.error.submit" : "kidsReview.detail.error",
                            tone: .error
                        )
                        .accessibilityIdentifier("kidsReview.detail.error")
                    }
                    header(detail)
                    metadata(detail)
                    noteSection(detail)
                    photoSection(detail)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.vertical, AppSpacing.lg)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { decisionBar }
        } else if viewModel.isUnavailable {
            stateCard(symbol: "checkmark.circle", message: "kidsReview.error.not_found", showsRetry: false)
                .accessibilityIdentifier("kidsReview.detail.unavailable")
        } else if viewModel.failed && !viewModel.isLoading {
            stateCard(symbol: "exclamationmark.triangle", message: "kidsReview.detail.error", showsRetry: true)
                .accessibilityIdentifier("kidsReview.detail.error")
        } else {
            // Also the state before the first load starts: a branch must always render, or the `.task` and
            // navigation title attached to `content` would be dropped with an empty view.
            loadingSkeleton
        }
    }

    private func load() async {
        lastAttempt = .load
        await viewModel.load()
    }

    private func decide(_ decision: KidsReviewDecision) async {
        lastAttempt = .decision
        await viewModel.decide(decision)
    }

    // MARK: Content

    private func header(_ detail: KidsSignalDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(detail.taskTitle)
                .font(.app(.title1))
                .foregroundStyle(Color.App.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                Image("TaskStatusAwaiting")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text("family.tasks.status.awaiting")
                    .font(.app(.noteStrong))
            }
            .foregroundStyle(Color.App.Text.primary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs + AppSpacing.xxs)
            // Neutral gray, borderless badge (Figma 870:27130).
            .background(Color.App.Status.neutralBackground, in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }

    private func metadata(_ detail: KidsSignalDetail) -> some View {
        VStack(spacing: 0) {
            metadataRow("kidsReview.detail.signaled_by", value: detail.childName)
                .accessibilityIdentifier("kidsReview.detail.signaled_by")
            FamilyCardSeparator()
            metadataRow(
                "kidsReview.detail.signaled_at",
                value: detail.signaledAt.formatted(date: .abbreviated, time: .shortened)
            )
            .accessibilityIdentifier("kidsReview.detail.signaled_at")
            FamilyCardSeparator()
            metadataRow("kidsReview.detail.assignees", value: detail.assignees.formatted(.list(type: .and)))
                .accessibilityIdentifier("kidsReview.detail.assignees")
        }
        .appCard(cornerRadius: AppRadius.pill)
    }

    private func metadataRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Text(label)
                .font(.app(.subtitle))
                .foregroundStyle(Color.App.Text.secondary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(.app(.subtitleStrong))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func noteSection(_ detail: KidsSignalDetail) -> some View {
        if let note = detail.taskNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                FamilySectionLabel("kidsReview.detail.note")
                Text(note)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .appCard(cornerRadius: AppRadius.pill)
            }
            .accessibilityIdentifier("kidsReview.detail.note")
        }
    }

    @ViewBuilder
    private func photoSection(_ detail: KidsSignalDetail) -> some View {
        if detail.photoMediaID != nil {
            FamilySectionLabel("kidsReview.detail.photo_section")
        }
        if detail.photoMediaID == nil {
            // Absence of a photo is not a failure (UX-013 §5.2).
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityHidden(true)
                Text("kidsReview.detail.no_photo")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.primary)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .appCard(cornerRadius: AppRadius.pill)
        } else if let photo = viewModel.photo, let image = UIImage(data: photo) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .background(Color.App.Background.subtle, in: RoundedRectangle(cornerRadius: AppRadius.card))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .accessibilityLabel("kidsReview.detail.photo")
                    .accessibilityAddTraits(.isImage)
                HStack(spacing: AppSpacing.xs + AppSpacing.xxs) {
                    Image(systemName: "lock")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)
                    Text("kidsReview.detail.private_photo_hint")
                        .font(.app(.note))
                }
                .foregroundStyle(Color.App.Text.secondary)
            }
            .padding(AppSpacing.md)
            .appCard(cornerRadius: AppRadius.pill)
            // The gesture lives on the card so the photo stays an image element (asserted by UI tests);
            // a tap or VoiceOver activation on it reaches the card and opens the private viewer.
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.pill))
            .onTapGesture { showsPhotoViewer = true }
        } else if viewModel.photoFailed {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                FamilyNoticeCard("kidsReview.detail.photo_error", tone: .error)
                Button("kidsReview.queue.retry") { Task { await load() } }
                    .buttonStyle(AppPillButtonStyle(kind: .secondary))
                    .disabled(viewModel.isLoading)
            }
        } else {
            RoundedRectangle(cornerRadius: AppRadius.pill)
                .fill(Color.App.Background.subtle)
                .frame(height: 224)
                .accessibilityLabel("kidsReview.detail.photo")
        }
    }

    // MARK: Decision

    /// Side by side on iPad / the split detail (Figma 870:27409), stacked on iPhone.
    private var decisionBar: some View {
        let layout = isEmbedded || horizontalSizeClass == .regular
            ? AnyLayout(HStackLayout(spacing: AppSpacing.md))
            : AnyLayout(VStackLayout(spacing: AppSpacing.sm))
        return layout {
            confirmButton
            Button { Task { await decide(.reject) } } label: {
                Text("kidsReview.decision.reject")
            }
            // White pill, chalk separator border, #423C1F label - never red (Figma 870:27166).
            .buttonStyle(AppPillButtonStyle(kind: .secondary))
            .disabled(viewModel.photoFailed || viewModel.isDeciding)
            .accessibilityIdentifier("kidsReview.detail.reject")
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .background(Color.App.Background.app)
    }

    /// While sending: light green "Salvando..." pill (Figma 870:27251). Taps are ignored instead of using
    /// `.disabled`, which would fade the pill; the ViewModel also rejects a second decision.
    private var confirmButton: some View {
        Button { Task { await decide(.confirm) } } label: {
            Text(viewModel.isDeciding ? "kidsReview.decision.submitting" : "kidsReview.decision.confirm")
        }
        .buttonStyle(AppPillButtonStyle(kind: viewModel.isDeciding ? .highlight : .primary))
        .allowsHitTesting(!viewModel.isDeciding)
        .disabled(viewModel.photoFailed)
        .accessibilityIdentifier("kidsReview.detail.confirm")
    }

    // MARK: States

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxl) {
            Capsule().fill(Color.App.Background.subtle).frame(width: 220, height: 28)
            Capsule().fill(Color.App.Background.subtle).frame(width: 170, height: 24)
            RoundedRectangle(cornerRadius: AppRadius.pill).fill(Color.App.Background.subtle).frame(height: 150)
            RoundedRectangle(cornerRadius: AppRadius.pill).fill(Color.App.Background.subtle).frame(height: 224)
            Spacer()
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: 540)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.overview.loading")
    }

    private func stateCard(symbol: String, message: LocalizedStringKey, showsRetry: Bool) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.App.Action.primary)
                .accessibilityHidden(true)
            Text(message)
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.primary)
                .multilineTextAlignment(.center)
            if showsRetry {
                Button("kidsReview.queue.retry") { Task { await load() } }
                    .buttonStyle(AppPillButtonStyle(kind: .primary))
            } else if !isEmbedded {
                Button("family.tasks.back") { dismiss() }
                    .buttonStyle(AppPillButtonStyle(kind: .secondary))
            }
        }
        .padding(AppSpacing.xxl)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .padding(AppSpacing.xxl)
        .frame(maxWidth: 540)
        .accessibilityElement(children: .contain)
    }
}

/// The pushed detail hides the navigation bar and shows its own circular back button (Figma 870:27124);
/// embedded in the iPad split it leaves the queue screen alone.
private struct DetailNavigationTitle: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
