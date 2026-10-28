import SwiftUI

/// MOD-009 — Editar perfil (Figma 567:294 adulto, 568:185 Kids, 568:449 iPad form sheet).
struct OwnProfileEditorView: View {
    @Bindable var viewModel: OwnProfileEditorViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case nickname
    }

    private var fieldHeight: CGFloat { viewModel.isKid ? 56 : 52 }

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
