import PhotosUI
import SwiftUI
import UIKit

/// TEL-055 — Perfil inicial do Criador (Figma node 268:1362).
struct InitialProfileView: View {
    @Bindable var viewModel: InitialOnboardingViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPhotosPickerPresented = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case nickname
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header: Título Grande + Subtítulo explicativo
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.profile.title")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(uiColor: .label))

                    Text("onboarding.profile.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .padding(.horizontal, 4)

                // Foto de perfil com ações
                avatarSection
                    .frame(maxWidth: .infinity)

                // Campo: Seu nome (obrigatório)
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.profile.name.section")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    HStack {
                        TextField("onboarding.profile.name.placeholder", text: $viewModel.name)
                            .font(.body)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                            .accessibilityIdentifier("profile.initial.name")

                        if viewModel.nameError != nil {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    HStack {
                        if let error = viewModel.nameError {
                            Label {
                                Text(error == .required ? "onboarding.profile.name.error_required" : "onboarding.profile.name.error_invalid")
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("profile.initial.name_error")
                        }
                        Spacer()
                        Text("\(viewModel.name.count)/60")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(.horizontal, 8)
                }

                // Campo: Etiqueta (opcional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.profile.nickname.section")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    HStack {
                        TextField("onboarding.profile.nickname.placeholder", text: $viewModel.nickname)
                            .font(.body)
                            .focused($focusedField, equals: .nickname)
                            .accessibilityIdentifier("profile.initial.nickname")

                        if viewModel.nicknameError {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    HStack {
                        if viewModel.nicknameError {
                            Label {
                                Text("onboarding.profile.nickname.error_invalid")
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("profile.initial.nickname_error")
                        }
                        Spacer()
                        Text("\(viewModel.nickname.filter { !$0.isWhitespace }.count)/20")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
            Button {
                viewModel.continueFromProfile()
            } label: {
                Text("onboarding.profile.continue")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isNameValid ? Color(uiColor: .systemBackground) : Color(uiColor: .secondaryLabel))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isNameValid ? Color.primary : Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .disabled(!isNameValid)
            .accessibilityIdentifier("profile.initial.continue")
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .onboardingColumn()
        }
        .photosPicker(isPresented: $isPhotosPickerPresented, selection: $pickerItem, matching: .images)
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
    }

    private var isNameValid: Bool {
        if case .success = FamilyCreationValidation.validatedName(viewModel.name) { return true }
        return false
    }

    private var avatarSection: some View {
        VStack(spacing: 8) {
            Menu {
                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label("onboarding.profile.photo.choose", systemImage: "photo.on.rectangle")
                }

                if viewModel.photo != nil {
                    Button(role: .destructive) {
                        viewModel.removePhoto()
                    } label: {
                        Label("onboarding.profile.photo.remove", systemImage: "trash")
                    }
                }
            } label: {
                VStack(spacing: 6) {
                    avatar
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .separator), lineWidth: 1)
                        )

                    Text(viewModel.photo == nil ? "onboarding.profile.photo.add" : "onboarding.profile.photo.change")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)

                    Text("onboarding.profile.photo.optional")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .accessibilityIdentifier("profile.initial.photo")

            if viewModel.photoSelectionFailed {
                FieldErrorText(
                    key: "onboarding.profile.photo.error_selection",
                    identifier: "profile.initial.photo_selection_error"
                )
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = viewModel.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(26)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
    }
}
