import SwiftUI

/// TEL-033 — local draft of an initial member (create or edit). Nothing is sent until the family exists.
struct InitialMemberDraftFormView: View {
    let viewModel: InitialOnboardingViewModel
    let member: DraftMember?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var role: MemberRole
    @State private var error: FamilyCreationValidation.TextError?

    init(viewModel: InitialOnboardingViewModel, member: DraftMember?) {
        self.viewModel = viewModel
        self.member = member
        _name = State(initialValue: member?.name ?? "")
        _role = State(initialValue: member?.role ?? .member)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("family.members.draft.name_label", text: $name)
                            .accessibilityIdentifier("family.members.draft.name")
                        if let error {
                            FieldErrorText(
                                key: error == .required
                                    ? "family.members.draft.error_required"
                                    : "family.members.draft.error_invalid",
                                identifier: "family.members.draft.name_error"
                            )
                        }
                    }
                    Picker("family.members.draft.role_label", selection: $role) {
                        ForEach(MemberRole.allCases, id: \.self) { role in
                            Text(role.onboardingTitleKey).tag(role)
                        }
                    }
                    .accessibilityIdentifier("family.members.draft.role")
                }

                if let member {
                    Section {
                        Button("family.members.draft.remove", role: .destructive) {
                            viewModel.removeMember(id: member.id)
                            dismiss()
                        }
                        .accessibilityIdentifier("family.members.draft.remove")
                    }
                }
            }
            .navigationTitle(member == nil ? "family.members.draft.title_new" : "family.members.draft.title_edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("family.members.draft.cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("family.members.draft.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("family.members.draft.save") {
                        error = viewModel.saveMember(id: member?.id, name: name, role: role)
                        if error == nil {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("family.members.draft.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
