import SwiftUI

/// TEL-015 — Confirmações Kids (UX-013 §5.1/§8; Figma 870:26988, iPad 870:27373).
/// iPhone (compact): single column that pushes TEL-016. iPad (regular): queue and TEL-016 side by side.
struct KidsReviewQueueView: View {
    @State private var viewModel: KidsReviewQueueViewModel
    /// Item open in the iPad split detail.
    @State private var selectedID: UUID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(viewModel: KidsReviewQueueViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isSplit: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isSplit {
                HStack(spacing: 0) {
                    queueColumn
                        .frame(width: 380)
                    Rectangle()
                        .fill(Color.App.Border.separator)
                        .frame(width: 1)
                        .ignoresSafeArea(edges: .bottom)
                    splitDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                queueColumn
            }
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        // Figma 870:26998: circular back button + large title instead of the navigation bar.
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .hidesAppTabBar()
        .task { await viewModel.load() }
        .onChange(of: horizontalSizeClass) { _, _ in
            // Entering the split (iPad rotation or multitasking resize) opens the first item.
            if isSplit, selectedID == nil { selectedID = viewModel.items.first?.id }
        }
        .onChange(of: viewModel.items) { _, items in
            // iPad: keep a valid selection — the first item on load, the next one after a decision.
            if isSplit, !items.contains(where: { $0.id == selectedID }) {
                selectedID = items.first?.id
            }
        }
    }

    // MARK: Queue column

    @Environment(\.dismiss) private var dismiss

    /// Header stays visible in every state, so the user can always go back.
    private var queueColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Button { dismiss() } label: {
                    FamilyCircleIconLabel(systemImage: "chevron.backward")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("family.tasks.back")
                .accessibilityIdentifier("kidsReview.queue.back")
                Text("kidsReview.queue.title")
                    .font(.app(.title1))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, isSplit ? AppSpacing.lg : AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .frame(maxWidth: 540, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            queueState
        }
    }

    @ViewBuilder
    private var queueState: some View {
        switch viewModel.viewState {
        case .loading:
            loadingSkeleton
        case .content:
            queue
        case .empty:
            stateCard {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.App.Action.primary)
                    .accessibilityHidden(true)
                Text("kidsReview.queue.empty")
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("kidsReview.queue.empty")
        case .failed:
            stateCard {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.App.Text.primary)
                    .accessibilityHidden(true)
                Text("kidsReview.queue.error_title")
                    .font(.app(.cardTitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.center)
                Text("kidsReview.queue.error_subtitle")
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
                    .multilineTextAlignment(.center)
                Button("kidsReview.queue.retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(AppPillButtonStyle(kind: .primary))
                .accessibilityIdentifier("kidsReview.queue.retry")
            }
        }
    }

    private var queue: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("kidsReview.queue.header")
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
                    .padding(.horizontal, AppSpacing.xs)
                // One grouped white card with separators (Figma 870:27005).
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { FamilyCardSeparator(leadingInset: AppSpacing.lg + 22 + AppSpacing.md) }
                        rowLink(item)
                            .accessibilityIdentifier("kidsReview.queue.row.\(item.id.uuidString.lowercased())")
                            .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
                .appCard(cornerRadius: AppRadius.pill)
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Color.App.Action.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                if viewModel.loadMoreFailed {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        FamilyNoticeCard("kidsReview.queue.error_title", tone: .error)
                        Button("kidsReview.queue.retry") {
                            Task { await viewModel.loadMore() }
                        }
                        .font(.app(.subtitleStrong))
                        .foregroundStyle(Color.App.Text.highlight)
                        .frame(minHeight: 44)
                        .padding(.leading, AppSpacing.lg)
                    }
                }
            }
            .padding(.horizontal, isSplit ? AppSpacing.lg : AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("kidsReview.queue.list")
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func rowLink(_ item: KidsSignalSummary) -> some View {
        if isSplit {
            Button { selectedID = item.id } label: {
                row(item, isSelected: selectedID == item.id)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
        } else {
            NavigationLink {
                KidsSignalDetailView(viewModel: viewModel.makeDetailViewModel(id: item.id)) {
                    Task { await viewModel.load() }
                }
                .hidesAppTabBar()
            } label: {
                row(item, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ item: KidsSignalSummary, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image("TaskStatusAwaiting")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.App.Text.secondary)
                .padding(.top, AppSpacing.xxs)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.taskTitle)
                    .font(.app(.cardTitle))
                    .foregroundStyle(Color.App.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(signaledByText(item))
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
                // Photo availability is text + icon, never color alone (RNF05).
                Label {
                    Text(item.hasPhoto ? "kidsReview.queue.with_photo" : "kidsReview.queue.no_photo")
                } icon: {
                    Image(systemName: item.hasPhoto ? "photo.fill" : "photo")
                }
                .font(.app(.noteStrong))
                .foregroundStyle(item.hasPhoto ? Color.App.Text.highlight : Color.App.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.App.Text.secondary)
                .padding(.top, AppSpacing.xs)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        // iPad: the open item is highlighted inside the grouped card (clipped by its rounded corners).
        .background(isSelected ? Color.App.Background.subtle : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func signaledByText(_ item: KidsSignalSummary) -> String {
        String(
            format: String(localized: "kidsReview.queue.item_signaled_by"),
            item.childName,
            item.signaledAt.formatted(date: .abbreviated, time: .shortened)
        )
    }

    // MARK: iPad detail column

    @ViewBuilder
    private var splitDetail: some View {
        if let selectedID {
            KidsSignalDetailView(viewModel: viewModel.makeDetailViewModel(id: selectedID), isEmbedded: true) {
                // The decided item leaves the queue; the selection moves to the next one (onChange of items).
                Task { await viewModel.load() }
            }
            .id(selectedID)
        } else {
            // Calm placeholder while loading, empty or failed: the queue column explains the state.
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.App.Border.cardHighlight)
                .accessibilityHidden(true)
        }
    }

    // MARK: States

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Capsule().fill(Color.App.Background.subtle).frame(width: 240, height: 12)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppRadius.pill)
                    .fill(Color.App.Background.subtle)
                    .frame(height: 96)
            }
            Spacer()
        }
        .padding(isSplit ? AppSpacing.lg : AppSpacing.xxl)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("family.overview.loading")
        .accessibilityIdentifier("kidsReview.queue.loading")
    }

    private func stateCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: AppSpacing.lg) {
            content()
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .appCard(cornerRadius: AppRadius.cardBoard)
        .padding(isSplit ? AppSpacing.lg : AppSpacing.xxl)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Children stay individually readable (UI tests read the texts and the retry button).
        .accessibilityElement(children: .contain)
    }
}
