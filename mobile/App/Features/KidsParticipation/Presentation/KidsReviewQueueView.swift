import SwiftUI

/// TEL-015 — Confirmações Kids (Figma nodes 577:435, 577:444, 577:537, 577:587, 577:646; UX-013 §5.1).
struct KidsReviewQueueView: View {
    @State private var viewModel: KidsReviewQueueViewModel

    init(viewModel: KidsReviewQueueViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("kidsReview.queue.loading")
            case .content:
                queue
            case .empty:
                ContentUnavailableView {
                    Label("kidsReview.queue.empty", systemImage: "checkmark.shield")
                }
                .accessibilityIdentifier("kidsReview.queue.empty")
            case .failed:
                ContentUnavailableView {
                    Label("kidsReview.queue.error_title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("kidsReview.queue.error_subtitle")
                } actions: {
                    Button("kidsReview.queue.retry") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("kidsReview.queue.retry")
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("kidsReview.queue.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var queue: some View {
        List {
            Section {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        KidsSignalDetailView(viewModel: viewModel.makeDetailViewModel(id: item.id)) {
                            Task { await viewModel.load() }
                        }
                    } label: {
                        row(item)
                    }
                        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                }
                if viewModel.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if viewModel.loadMoreFailed {
                    Button("kidsReview.queue.retry") {
                        Task { await viewModel.loadMore() }
                    }
                }
            } header: {
                Text("kidsReview.queue.header")
                    .textCase(nil)
            }
        }
        .accessibilityIdentifier("kidsReview.queue.list")
        .refreshable { await viewModel.load() }
    }

    private func row(_ item: KidsSignalSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.taskTitle)
                .font(.body.weight(.semibold))
            Text(signaledByText(item))
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Label {
                Text(item.hasPhoto ? "kidsReview.queue.with_photo" : "kidsReview.queue.no_photo")
            } icon: {
                Image(systemName: item.hasPhoto ? "photo" : "photo.slash")
            }
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("kidsReview.queue.row.\(item.id.uuidString.lowercased())")
    }

    private func signaledByText(_ item: KidsSignalSummary) -> String {
        String(
            format: String(localized: "kidsReview.queue.item_signaled_by"),
            item.childName,
            item.signaledAt.formatted(date: .abbreviated, time: .shortened)
        )
    }
}
