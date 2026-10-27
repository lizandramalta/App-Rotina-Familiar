import PhotosUI
import SwiftUI
import UIKit

/// MOD-009 — Editar perfil (Figma 567:294 adulto, 568:185 Kids, 568:449 iPad form sheet).
struct OwnProfileEditorView: View {
    @Bindable var viewModel: OwnProfileEditorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPhotoDialogPresented = false
    @State private var isPhotosPickerPresented = false
    @State private var isCameraPresented = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case nickname
    }

    private var fieldHeight: CGFloat { viewModel.isKid ? 56 : 52 }
    private var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let banner = viewModel.bannerError {
                        errorBanner(banner)
                    }
                    if !viewModel.isKid {
                        Text("profile.edit.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    photoBlock.frame(maxWidth: .infinity)
                    if !viewModel.isKid { nameField }
                    nicknameField
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("profile.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationSizing(.form)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .confirmationDialog("profile.edit.photo_dialog_title", isPresented: $isPhotoDialogPresented, titleVisibility: .hidden) {
            if isCameraAvailable {
                Button("profile.edit.photo_take") { isCameraPresented = true }
            }
            Button("profile.edit.photo_pick") { isPhotosPickerPresented = true }
            if viewModel.currentMediaID != nil {
                Button("profile.edit.photo_remove", role: .destructive) { viewModel.removePhoto() }
            }
            Button("profile.edit.photo_dialog_cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isPhotosPickerPresented, selection: $pickerItem, matching: .images)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker { data in
                isCameraPresented = false
                guard let data else { return }
                Task { await viewModel.selectPhoto(from: data) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.selectPhoto(from: data)
                } else {
                    viewModel.reportPhotoSelectionFailure()
                }
                pickerItem = nil
            }
        }
        .alert("profile.edit.discard_title", isPresented: $viewModel.isShowingDiscardConfirmation) {
            Button("profile.edit.discard_confirm", role: .destructive) { viewModel.confirmDiscard() }
                .accessibilityIdentifier("profile.edit.discard_confirm")
            Button("profile.edit.discard_cancel", role: .cancel) {}
                .accessibilityIdentifier("profile.edit.discard_cancel")
        } message: {
            Text("profile.edit.discard_message")
        }
    }

    // MARK: Top bar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                viewModel.requestClose()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("profile.edit.close")
            .accessibilityIdentifier("profile.edit.close")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark")
                }
            }
            .disabled(!viewModel.canSave)
            .accessibilityLabel(viewModel.isSaving ? "profile.edit.saving" : "profile.edit.save")
            .accessibilityHint("profile.edit.save_hint")
            .accessibilityIdentifier("profile.edit.save")
        }
    }

    // MARK: Banner

    private func errorBanner(_ banner: EditorBanner) -> some View {
        Label {
            Text(banner == .network ? "profile.edit.error_network" : "profile.edit.error_unavailable")
        } icon: {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("profile.edit.error_banner")
    }

    // MARK: Photo

    private var photoBlock: some View {
        VStack(spacing: 10) {
            avatar
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay {
                    if viewModel.isUploadingPhoto {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }

            if viewModel.isUploadingPhoto {
                Text("profile.edit.photo_uploading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.edit.photo_uploading")
                Button("profile.edit.photo_cancel_upload") { viewModel.cancelPhotoUpload() }
                    .frame(minHeight: viewModel.isKid ? 56 : 44)
                    .accessibilityIdentifier("profile.edit.photo_cancel_upload")
            } else {
                Button {
                    isPhotoDialogPresented = true
                } label: {
                    Text(viewModel.currentMediaID == nil ? "profile.edit.photo_add" : "profile.edit.photo_change")
                        .font(.body.weight(.medium))
                        .frame(minWidth: 44, minHeight: viewModel.isKid ? 56 : 44)
                }
                .accessibilityIdentifier("profile.edit.photo_button")

                Text(viewModel.isKid ? "profile.edit.photo_caption_kids" : "profile.edit.photo_caption")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.photoError {
                photoErrorCard(error)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = viewModel.currentAvatarData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color(uiColor: .tertiarySystemFill))
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(26)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("profile.avatar.default")
        }
    }

    private func photoErrorCard(_ error: PhotoErrorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(photoErrorMessage(error))
            } icon: {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            }
            .font(.subheadline)
            .accessibilityIdentifier("profile.edit.photo_error")

            HStack(spacing: 16) {
                switch error {
                case .uploadFailed:
                    Button("profile.edit.photo_retry") { Task { await viewModel.retryPhotoUpload() } }
                        .accessibilityIdentifier("profile.edit.photo_retry")
                    Button("profile.edit.photo_keep") { viewModel.keepCurrentPhoto() }
                        .accessibilityIdentifier("profile.edit.photo_keep")
                case .formatUnsupported, .tooLarge:
                    Button("profile.edit.photo_choose_another") {
                        viewModel.keepCurrentPhoto()
                        isPhotoDialogPresented = true
                    }
                    .accessibilityIdentifier("profile.edit.photo_choose_another")
                case .processingNotReady:
                    Button("profile.edit.photo_retry") { Task { await viewModel.save() } }
                        .accessibilityIdentifier("profile.edit.photo_retry")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: viewModel.isKid ? 56 : 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func photoErrorMessage(_ error: PhotoErrorState) -> LocalizedStringKey {
        switch error {
        case .uploadFailed: "profile.edit.error_photo_upload"
        case .formatUnsupported: "profile.edit.error_photo_format"
        case .tooLarge: "profile.edit.error_photo_too_large"
        case .processingNotReady: "profile.edit.error_photo_processing"
        }
    }

    // MARK: Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("profile.edit.name_label")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            roundedField {
                TextField("profile.edit.name_label", text: $viewModel.name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .accessibilityIdentifier("profile.edit.name")
            }

            HStack {
                if let error = viewModel.nameError {
                    FieldErrorText(
                        key: error == .required ? "onboarding.profile.name.error_required" : "onboarding.profile.name.error_invalid",
                        identifier: "profile.edit.name_error"
                    )
                }
                Spacer()
                Text("\(viewModel.name.count)/60")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
        }
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.isKid ? "profile.edit.nickname_label_kids" : "profile.edit.nickname_label")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            roundedField {
                TextField(
                    viewModel.isKid ? "profile.edit.nickname_label_kids" : "profile.edit.nickname_placeholder",
                    text: $viewModel.nickname
                )
                .focused($focusedField, equals: .nickname)
                .accessibilityIdentifier("profile.edit.nickname")
            }

            HStack {
                if viewModel.nicknameError != nil {
                    FieldErrorText(
                        key: viewModel.isKid ? "profile.edit.nickname_error_kids" : "profile.edit.nickname_error",
                        identifier: "profile.edit.nickname_error"
                    )
                }
                Spacer()
                Text("\(viewModel.nicknameNonWhitespaceCount)/20")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityIdentifier("profile.edit.nickname_counter")
            }
            .padding(.horizontal, 8)

            Text(viewModel.isKid ? "profile.edit.nickname_help_kids" : "profile.edit.nickname_help")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func roundedField(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 20)
            .frame(height: fieldHeight)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Camera capture for "Tirar foto"; returns the raw JPEG, which the normalizer then resizes and strips.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
