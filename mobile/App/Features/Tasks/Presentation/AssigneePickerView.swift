import SwiftUI

/// MOD-001 — edits a local draft; Cancelar discards it, Confirmar returns the selection to TEL-013.
/// Kids members can be assignees like anyone else (RN12); the "Kids" tag only identifies them (UX-007 UX-08).
struct AssigneePickerView: View {
    @Bindable var viewModel: TaskEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftSelection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingMembers {
                    ProgressView()
                } else if viewModel.membersLoadFailed {
                    ContentUnavailableView {
                        Label("tasks.detail.load_error", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Tentar novamente") { Task { await viewModel.loadAssigneeCandidatesIfNeeded() } }
                    }
                } else {
                    List(viewModel.orderedMembers) { member in
                        Button {
                            toggle(member.id)
                        } label: {
                            row(for: member, isSelected: draftSelection.contains(member.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draftSelection.contains(member.id) ? [.isSelected] : [])
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .accessibilityIdentifier("tasks.assignee_picker.row.\(member.id.uuidString)")
                    }
                    // Prototype spacing: the list starts 8 pt below the bar, with 52 pt rows.
                    .contentMargins(.top, 8, for: .scrollContent)
                    // A short family list stays still instead of bouncing under the bar.
                    .scrollBounceBehavior(.basedOnSize)
                    .environment(\.defaultMinListRowHeight, 52)
                }
            }
            .navigationTitle("tasks.form.assignees_label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Cancelar"))
                    .accessibilityIdentifier("tasks.assignee_picker.cancel")
                }
                // `.confirmationAction` renders the prominent filled ✓ circle of the prototype.
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.setAssignees(draftSelection)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel(Text("Confirmar"))
                    .accessibilityIdentifier("tasks.assignee_picker.confirm")
                }
            }
        }
        .task {
            draftSelection = viewModel.assigneeIDs
            await viewModel.loadAssigneeCandidatesIfNeeded()
        }
    }

    private func row(for member: FamilyMember, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Decorative: VoiceOver already reads the name (UX-007 UX-07).
            Text(viewModel.displayName(for: member).prefix(1).uppercased())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .systemGray5), in: Circle())
                .accessibilityHidden(true)
            Text(viewModel.displayName(for: member))
                .foregroundStyle(.primary)
                // The separator starts under the name, not under the avatar.
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            if member.role == .kid {
                Text("tasks.assignee_picker.kids_tag")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(uiColor: .separator)))
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func toggle(_ id: UUID) {
        if draftSelection.contains(id) {
            draftSelection.remove(id)
        } else {
            draftSelection.insert(id)
        }
    }
}
