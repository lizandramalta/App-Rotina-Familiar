import SwiftUI

/// TEL-033 — Adicionar membro (Figma node 186:1292, UX-003 §5.3).
struct MemberEditorView: View {
    @Bindable var viewModel: MemberEditorViewModel
    let onCreated: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDiscardConfirmationPresented = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                nameSection
                roleSection
                if let message = viewModel.generalError {
                    FamilyNoticeCard(message, tone: .error)
                        .accessibilityIdentifier("family.members.editor.error")
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxxl)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("family.members.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .hidesAppTabBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("family.members.draft.cancel") {
                    if viewModel.hasUnsavedChanges {
                        isDiscardConfirmationPresented = true
                    } else {
                        dismiss()
                    }
                }
                .tint(Color.App.Action.primary)
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("family.members.editor.cancel")
            }
        }
        .safeAreaInset(edge: .bottom) { submitBar }
        .confirmationDialog(
            "family.members.discard.title",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("family.members.discard.confirm", role: .destructive) { dismiss() }
            Button("family.members.discard.keep_editing", role: .cancel) {}
        } message: {
            Text("family.members.discard.message")
        }
        .onAppear { isNameFocused = true }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.members.name.label")

            HStack {
                TextField("family.members.name.label", text: $viewModel.name)
                    .font(.app(.body))
                    .foregroundStyle(Color.App.Text.primary)
                    .focused($isNameFocused)
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("family.members.editor.name")

                if viewModel.nameError != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.App.System.destructive)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .frame(minHeight: 52)
            .appCard(cornerRadius: AppRadius.pill)

            HStack(alignment: .top) {
                if viewModel.nameError != nil {
                    Label {
                        Text("family.members.name.error_invalid")
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .font(.app(.note))
                    .foregroundStyle(Color.App.System.destructive)
                    .accessibilityIdentifier("family.members.editor.name_error")
                } else {
                    Text("family.members.name.hint")
                        .font(.app(.note))
                        .foregroundStyle(Color.App.Text.secondary)
                }
                Spacer()
                Text("\(viewModel.name.count)/\(FamilyCreationValidation.nameLimit)")
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            FamilySectionLabel("family.members.role.label")

            VStack(spacing: 0) {
                ForEach(Array(MemberRole.allCases.enumerated()), id: \.element) { index, option in
                    if index > 0 { FamilyCardSeparator(leadingInset: AppSpacing.lg + 28 + AppSpacing.md) }
                    Button {
                        viewModel.role = option
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: option.editorSymbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.App.Action.primary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(option.onboardingTitleKey)
                                    .font(.app(.body))
                                    .foregroundStyle(Color.App.Text.primary)
                                Text(option.editorDescriptionKey)
                                    .font(.app(.note))
                                    .foregroundStyle(Color.App.Text.secondary)
                            }
                            Spacer()
                            if viewModel.role == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.App.Action.primary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .accessibilityAddTraits(viewModel.role == option ? .isSelected : [])
                    .accessibilityIdentifier("family.members.editor.role.\(option.rawValue)")
                }
            }
            .appCard(cornerRadius: AppRadius.pill)
        }
    }

    private var submitBar: some View {
        Button {
            Task {
                if await viewModel.save() {
                    onCreated()
                    dismiss()
                }
            }
        } label: {
            if viewModel.isLoading {
                ProgressView().tint(Color.App.Text.onAction)
            } else {
                Text("family.members.create.title")
            }
        }
        .buttonStyle(AppPillButtonStyle(kind: .primary))
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("family.members.editor.submit")
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .background(Color.App.Background.app)
    }
}

private extension MemberRole {
    var editorSymbol: String {
        switch self {
        case .administrator: "person.badge.key.fill"
        case .member: "person.fill"
        case .kid: "figure.and.child.holdinghands"
        }
    }

    var editorDescriptionKey: LocalizedStringKey {
        switch self {
        case .administrator: "family.members.role.administrator.description"
        case .member: "family.members.role.member.description"
        case .kid: "family.members.role.kids.description"
        }
    }
}
