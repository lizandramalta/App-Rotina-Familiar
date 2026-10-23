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
            VStack(alignment: .leading, spacing: 28) {
                nameSection
                roleSection
                if let message = viewModel.generalError {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("family.members.editor.error")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("family.members.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("family.members.draft.cancel") {
                    if viewModel.hasUnsavedChanges {
                        isDiscardConfirmationPresented = true
                    } else {
                        dismiss()
                    }
                }
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
        VStack(alignment: .leading, spacing: 6) {
            Text("family.members.name.label")
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 4)

            HStack {
                TextField("family.members.name.label", text: $viewModel.name)
                    .font(.body)
                    .focused($isNameFocused)
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("family.members.editor.name")

                if viewModel.nameError != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            HStack(alignment: .top) {
                if viewModel.nameError != nil {
                    Label {
                        Text("family.members.name.error_invalid")
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("family.members.editor.name_error")
                } else {
                    Text("family.members.name.hint")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                Text("\(viewModel.name.count)/\(FamilyCreationValidation.nameLimit)")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, 8)
        }
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("family.members.role.label")
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(MemberRole.allCases.enumerated()), id: \.element) { index, option in
                    Button {
                        viewModel.role = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.onboardingTitleKey)
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .label))
                                Text(option.editorDescriptionKey)
                                    .font(.footnote)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                            Spacer()
                            if viewModel.role == option {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .accessibilityAddTraits(viewModel.role == option ? .isSelected : [])
                    .accessibilityIdentifier("family.members.editor.role.\(option.rawValue)")

                    if index < MemberRole.allCases.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("family.members.create.title")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("family.members.editor.submit")
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onboardingColumn()
        .background(.bar)
    }
}

private extension MemberRole {
    var editorDescriptionKey: LocalizedStringKey {
        switch self {
        case .administrator: "family.members.role.administrator.description"
        case .member: "family.members.role.member.description"
        case .kid: "family.members.role.kids.description"
        }
    }
}
