import SwiftUI
import UIKit

/// MOD-011 — optional direct camera photo before signaling a Kids task.
struct KidsSignalSheet: View {
    @Bindable var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var capturedPhoto: Data?
    @State private var showsCamera = false
    @State private var showsCameraUnavailableNotice = false
    @State private var showsDiscardConfirmation = false

    private static let headerControlSize: CGFloat = 44
    private static let taskIconSize: CGFloat = 28
    private static let photoHeight: CGFloat = 180
    private static let photoActionHeight: CGFloat = 52
    private static let photoActionSpacing: CGFloat = 10
    private static let topPadding: CGFloat = 10

    /// Figma 907:26030: compact white sheet with its own header (no navigation bar), as MOD-006.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                taskRow
                photoArea
                if showsCameraUnavailableNotice, capturedPhoto == nil {
                    feedback {
                        Label("kids.signal.camera_unavailable", systemImage: "camera.badge.ellipsis")
                            .foregroundStyle(Color.App.Text.primary)
                    }
                }
                if viewModel.photoUploadFailed {
                    feedback {
                        Label("kids.signal.photo_failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.App.System.destructive)
                        feedbackAction("kids.signal.without_photo") { Task { await submit(photo: nil) } }
                    }
                }
                if viewModel.signalNeedsRefresh {
                    feedback {
                        Label("kids.signal.refresh_needed", systemImage: "arrow.clockwise")
                            .foregroundStyle(Color.App.Text.primary)
                        feedbackAction("kidsReview.queue.retry") { Task { await viewModel.load() } }
                    }
                } else if viewModel.signalFailed {
                    feedback {
                        Label("kids.signal.failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.App.System.destructive)
                    }
                }
                submitButton
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, Self.topPadding)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationBackground(Color.App.Background.card)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A captured photo can only be discarded through the close button's confirmation.
        .interactiveDismissDisabled(viewModel.isSignaling || capturedPhoto != nil)
        .alert("kids.signal.discard_title", isPresented: $showsDiscardConfirmation) {
            Button("kids.signal.discard_cancel", role: .cancel) {}
            Button("kids.signal.discard_confirm", role: .destructive) {
                capturedPhoto = nil
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in
                showsCamera = false
                if let data { capturedPhoto = data }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            // Balances the close button so the title stays centered.
            Color.clear.frame(width: Self.headerControlSize, height: Self.headerControlSize)
            Spacer(minLength: 0)
            Text("kids.signal.title")
                .font(.app(.title2))
                .foregroundStyle(Color.App.Text.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                // UX-01: leaving with an unsent photo asks first (Figma 907:26638).
                if capturedPhoto != nil {
                    showsDiscardConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.app(.bodyStrong))
                    .foregroundStyle(Color.App.Text.primary)
                    .frame(width: Self.headerControlSize, height: Self.headerControlSize)
                    .background(Color.App.Background.cardHighlight, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSignaling)
            .opacity(viewModel.isSignaling ? 0.4 : 1)
            .accessibilityLabel(Text("family.settings.hub.cancel"))
            .accessibilityIdentifier("kids.signal.close")
        }
    }

    /// Figma 907:26090: which task is being signaled.
    private var taskRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: "list.bullet")
                .font(.app(.title2))
                .foregroundStyle(Color.App.Action.primary)
                .frame(width: Self.taskIconSize, height: Self.taskIconSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let title = viewModel.task?.title {
                    Text(title)
                        .font(.app(.bodyStrong))
                        .foregroundStyle(Color.App.Text.primary)
                }
                Text("kids.signal.explanation")
                    .font(.app(.caption))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var photoArea: some View {
        if let capturedPhoto, let image = UIImage(data: capturedPhoto) {
            Color.App.Background.cardHighlight
                .frame(maxWidth: .infinity)
                .frame(height: Self.photoHeight)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("kids.signal.photo_preview"))
            HStack(spacing: Self.photoActionSpacing) {
                Button(action: openCamera) {
                    Label("kids.signal.take_photo", systemImage: "camera.rotate")
                }
                .buttonStyle(AppPillButtonStyle(kind: .highlight, height: Self.photoActionHeight))
                Button(role: .destructive) {
                    self.capturedPhoto = nil
                } label: {
                    Label("kids.signal.remove_photo", systemImage: "trash")
                }
                .buttonStyle(AppPillButtonStyle(
                    kind: .highlight,
                    height: Self.photoActionHeight,
                    foreground: Color.App.System.destructive
                ))
            }
        } else {
            Button(action: openCamera) {
                Label("kids.signal.take_photo", systemImage: "camera")
            }
            .buttonStyle(AppPillButtonStyle(kind: .highlight, height: AppPillButtonStyle.kidsHeight))
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit(photo: capturedPhoto) }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isSignaling {
                    ProgressView().tint(Color.App.Text.onAction)
                }
                Text("kids.signal.submit")
            }
        }
        .buttonStyle(AppPillButtonStyle(kind: .primary, height: AppPillButtonStyle.kidsHeight))
        .disabled(viewModel.isSignaling || viewModel.signalNeedsRefresh || !viewModel.canSignal)
        .accessibilityIdentifier("kids.signal.submit")
    }

    /// RN54: direct camera only, never the photo library. Where there is no camera (e.g. the
    /// simulator) a non-blocking notice explains it; signaling without a photo stays available.
    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showsCamera = true
        } else {
            showsCameraUnavailableNotice = true
        }
    }

    private func feedback<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .font(.app(.subtitle))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            // Figma 907:26471: flat app-background box with a secondary outline.
            .background(Color.App.Background.app, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .strokeBorder(Color.App.Text.secondary, lineWidth: 1.5)
            )
    }

    private func feedbackAction(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.Action.primary)
    }

    private func submit(photo: Data?) async {
        await viewModel.sendSignal(photoData: photo)
        if viewModel.task?.status == .awaitingConfirmation { dismiss() }
    }
}
