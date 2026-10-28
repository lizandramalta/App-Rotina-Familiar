import SwiftUI

/// TEL-033 — Criar/editar membro (Figma node 186:1292).
struct InitialMemberDraftFormView: View {
    let viewModel: InitialOnboardingViewModel
    let member: DraftMember?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var role: MemberRole
    @State private var error: FamilyCreationValidation.TextError?
    @State private var isDiscardConfirmationPresented = false
    @FocusState private var isNameFocused: Bool

    private let initialName: String
    private let initialRole: MemberRole

    init(viewModel: InitialOnboardingViewModel, member: DraftMember?) {
        self.viewModel = viewModel
        self.member = member
        let initialNameValue = member?.name ?? ""
        let initialRoleValue = member?.role ?? .member
        _name = State(initialValue: initialNameValue)
        _role = State(initialValue: initialRoleValue)
        self.initialName = initialNameValue
        self.initialRole = initialRoleValue
    }

    private var hasUnsavedChanges: Bool {
        name != initialName || role != initialRole
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Seção: Nome do membro
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.members.draft.name_label")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    HStack {
                        TextField("family.members.draft.name_placeholder", text: $name)
                            .font(.body)
                            .focused($isNameFocused)
                            .accessibilityIdentifier("family.members.draft.name")

                        if error != nil {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    HStack(alignment: .top) {
                        if let error {
                            Label {
                                Text(error == .required
                                    ? "family.members.draft.error_required"
                                    : "family.members.draft.error_invalid")
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("family.members.draft.name_error")
                        } else {
                            Text("family.members.draft.name_footer")
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        Spacer()
                        Text("\(name.count)/60")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(.horizontal, 8)
                }

                // Seção: Papel na família
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.members.draft.role_label")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(MemberRole.allCases.filter { $0 != .kid }.enumerated()), id: \.element) { index, option in
                            Button {
                                role = option
                            } label: {
                                HStack {
                                    Text(option.onboardingTitleKey)
                                        .font(.body)
                                        .foregroundStyle(Color(uiColor: .label))

                                    Spacer()

                                    if role == option {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.primary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("family.members.draft.role.\(option.rawValue)")

                            if index < MemberRole.allCases.filter({ $0 != .kid }).count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .accessibilityIdentifier("family.members.draft.role")

                    Text("family.members.draft.role_footer")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 8)
                }

                // Seção: Remover membro (somente em edição)
                if let member {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            viewModel.removeMember(id: member.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.red)

                                Text("family.members.draft.remove")
                                    .font(.body)
                                    .foregroundStyle(.red)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("family.members.draft.remove")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(member == nil ? "family.members.draft.title_new" : "family.members.draft.title_edit")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasUnsavedChanges {
                        isDiscardConfirmationPresented = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                }
                .accessibilityIdentifier("family.members.draft.back")
                .accessibilityLabel("Voltar")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    error = viewModel.saveMember(id: member?.id, name: name, role: role)
                    if error == nil {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                }
                .accessibilityIdentifier("family.members.draft.save")
                .accessibilityLabel("Salvar")
            }
        }
        .confirmationDialog(
            "family.members.discard.title",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("family.members.discard.confirm", role: .destructive) {
                dismiss()
            }
            .accessibilityIdentifier("family.members.draft.discard_confirm")

            Button("family.members.discard.keep_editing", role: .cancel) {}
                .accessibilityIdentifier("family.members.draft.discard_cancel")
        } message: {
            Text("family.members.discard.message")
        }
    }
}
