import SwiftUI

/// MOD-001 — edits a local draft; Cancelar discards it, Confirmar returns the selection to TEL-013.
/// Kids members are listed like any other member, with no visual distinction (SPEC-007 §4, RN12).
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
                    List(viewModel.availableMembers) { member in
                        Button {
                            toggle(member.id)
                        } label: {
                            HStack {
                                Text(member.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if draftSelection.contains(member.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("tasks.assignee_picker.row.\(member.id.uuidString)")
                    }
                    .safeAreaInset(edge: .bottom) {
                        Text("tasks.form.assignees_footer")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
            .navigationTitle("tasks.form.assignees_label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .accessibilityIdentifier("tasks.assignee_picker.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        viewModel.setAssignees(draftSelection)
                        dismiss()
                    }
                    .accessibilityIdentifier("tasks.assignee_picker.confirm")
                }
            }
        }
        .task {
            draftSelection = viewModel.assigneeIDs
            await viewModel.loadAssigneeCandidatesIfNeeded()
        }
    }

    private func toggle(_ id: UUID) {
        if draftSelection.contains(id) {
            draftSelection.remove(id)
        } else {
            draftSelection.insert(id)
        }
    }
}
