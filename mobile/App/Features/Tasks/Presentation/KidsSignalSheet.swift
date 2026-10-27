import SwiftUI
import UIKit

/// MOD-011 — optional direct camera photo before signaling a Kids task.
struct KidsSignalSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var capturedPhoto: Data?
    @State private var showsCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("kids.signal.explanation")
                        .font(.body)
                    if let capturedPhoto, let image = UIImage(data: capturedPhoto) {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .accessibilityLabel("kids.signal.photo_preview")
                        Button("kids.signal.remove_photo", role: .destructive) { self.capturedPhoto = nil }
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("kids.signal.take_photo", systemImage: "camera") { showsCamera = true }
                    }
                    if viewModel.photoUploadFailed {
                        Label("kids.signal.photo_failed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("kids.signal.without_photo") { Task { await submit(photo: nil) } }
                    }
                    if viewModel.signalNeedsRefresh {
                        Label("kids.signal.refresh_needed", systemImage: "arrow.clockwise")
                        Button("kidsReview.queue.retry") { Task { await viewModel.load() } }
                    } else if viewModel.signalFailed {
                        Label("kids.signal.failed", systemImage: "exclamationmark.triangle")
                    }
                    Button("kids.signal.submit") { Task { await submit(photo: capturedPhoto) } }
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
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in
                showsCamera = false
                if let data { capturedPhoto = data }
            }
            .ignoresSafeArea()
        }
    }

    private func submit(photo: Data?) async {
        await viewModel.sendSignal(photoData: photo)
        if viewModel.task?.status == .awaitingConfirmation { dismiss() }
    }
}
