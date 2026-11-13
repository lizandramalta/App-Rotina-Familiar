import SwiftUI

/// TEL-016 — inspect a current Kids signal and explicitly confirm or reject it.
struct KidsSignalDetailView: View {
    @State private var viewModel: KidsSignalDetailViewModel
    let onResolved: () -> Void

    init(viewModel: KidsSignalDetailViewModel, onResolved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onResolved = onResolved
    }

    var body: some View {
        List {
            if let detail = viewModel.detail {
                Section {
                    Text(detail.taskTitle).font(.headline)
                    LabeledContent("kidsReview.detail.assignees") {
                        Text(detail.assignees.formatted(.list(type: .and)))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("kidsReview.detail.assignees")
                    LabeledContent("kidsReview.detail.signaled_by") {
                        Text(detail.childName)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("kidsReview.detail.signaled_by")
                    LabeledContent("kidsReview.detail.signaled_at") {
                        Text(detail.signaledAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("kidsReview.detail.signaled_at")
                }
                Section {
                    if detail.photoMediaID == nil {
                        Label("kidsReview.detail.no_photo", systemImage: "photo.on.rectangle.angled")
                    } else if let photo = viewModel.photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel("kidsReview.detail.photo")
                    } else if viewModel.photoFailed {
                        Label("kidsReview.detail.photo_error", systemImage: "exclamationmark.triangle")
                        Button("kidsReview.queue.retry") { Task { await viewModel.load() } }
                    } else {
                        ProgressView()
                    }
                }
                Section {
                    Button("kidsReview.detail.confirm") { Task { await viewModel.decide(.confirm) } }
                        .disabled(viewModel.isDeciding || viewModel.photoFailed)
                    Button("kidsReview.detail.reject", role: .destructive) { Task { await viewModel.decide(.reject) } }
                        .disabled(viewModel.isDeciding || viewModel.photoFailed)
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
            if viewModel.failed {
                Section {
                    Label("kidsReview.detail.error", systemImage: "exclamationmark.triangle")
                    Button("kidsReview.queue.retry") { Task { await viewModel.load() } }
                }
            }
            if viewModel.resolved {
                ContentUnavailableView("kidsReview.detail.resolved", systemImage: "checkmark.shield")
            }
        }
        .navigationTitle("kidsReview.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: viewModel.resolved) { _, resolved in if resolved { onResolved() } }
    }
}
