import PhotosUI
import SwiftUI
import UIKit

/// TEL-055 — local draft of the creator profile.
struct InitialProfileView: View {
    @Bindable var viewModel: InitialOnboardingViewModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                avatarSection
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("onboarding.profile.name.label")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("onboarding.profile.name.placeholder", text: $viewModel.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("profile.initial.name")
                    if let error = viewModel.nameError {
                        FieldErrorText(
                            key: error == .required
                                ? "onboarding.profile.name.error_required"
                                : "onboarding.profile.name.error_invalid",
                            identifier: "profile.initial.name_error"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("onboarding.profile.nickname.label")
                        Spacer()
                        Text("onboarding.profile.nickname.optional")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    TextField("onboarding.profile.nickname.placeholder", text: $viewModel.nickname)
                        .accessibilityIdentifier("profile.initial.nickname")
                    if viewModel.nicknameError {
                        FieldErrorText(
                            key: "onboarding.profile.nickname.error_invalid",
                            identifier: "profile.initial.nickname_error"
                        )
                    }
                }
            } header: {
                Text("onboarding.profile.section")
            } footer: {
                Text("onboarding.profile.nickname.footer")
            }
        }
        .onboardingColumn()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("onboarding.profile.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("onboarding.profile.cancel") {
                    viewModel.requestDiscard()
                }
                .accessibilityIdentifier("profile.initial.cancel")
            }
        }
        .confirmationDialog(
            "onboarding.discard.title",
            isPresented: $viewModel.isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("onboarding.discard.confirm", role: .destructive) {
                viewModel.discard()
            }
            .accessibilityIdentifier("profile.initial.discard_confirm")
            Button("onboarding.discard.keep_editing", role: .cancel) {}
        } message: {
            Text("onboarding.discard.message")
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingPrimaryButton(title: "onboarding.profile.continue", identifier: "profile.initial.continue") {
                viewModel.continueFromProfile()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else {
                return
            }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.selectPhoto(from: data)
                } else {
                    viewModel.reportPhotoSelectionFailure()
                }
                pickerItem = nil
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                avatar
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.initial.photo")
            .accessibilityLabel(Text(photoActionKey))

            HStack(spacing: 16) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(photoActionKey)
                }
                if viewModel.photo != nil {
                    Button("onboarding.profile.photo.remove", role: .destructive) {
                        viewModel.removePhoto()
                    }
                    .accessibilityIdentifier("profile.initial.photo_remove")
                }
            }
            .font(.subheadline)

            if viewModel.photoSelectionFailed {
                FieldErrorText(
                    key: "onboarding.profile.photo.error_selection",
                    identifier: "profile.initial.photo_selection_error"
                )
            }
        }
    }

    private var photoActionKey: LocalizedStringKey {
        viewModel.photo == nil ? "onboarding.profile.photo.add" : "onboarding.profile.photo.change"
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let data = viewModel.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }
}
