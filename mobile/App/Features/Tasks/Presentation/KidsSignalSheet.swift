import SwiftUI

/// Legacy Kids signal sheet kept for the full product; the TestFlight app cannot reach it.
struct KidsSignalSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("kids.signal.explanation")
                        .font(.body)
                    if viewModel.signalNeedsRefresh {
                        Label("kids.signal.refresh_needed", systemImage: "arrow.clockwise")
                        Button("kidsReview.queue.retry") { Task { await viewModel.load() } }
                    } else if viewModel.signalFailed {
                        Label("kids.signal.failed", systemImage: "exclamationmark.triangle")
                    }
                    Button("kids.signal.submit") { Task { await submit() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSignaling || viewModel.signalNeedsRefresh || !viewModel.canSignal)
                    if viewModel.isSignaling { ProgressView() }
                }
                .padding(20)
            }
            .navigationTitle("kids.signal.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("family.settings.hub.cancel") { dismiss() }
                }
            }
        }
        .presentationSizing(.form)
    }

    private func submit() async {
        await viewModel.sendSignal(photoData: nil)
        if viewModel.task?.status == .awaitingConfirmation { dismiss() }
    }
}
