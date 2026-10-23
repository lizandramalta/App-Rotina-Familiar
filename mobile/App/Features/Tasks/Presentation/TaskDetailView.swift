import SwiftUI

/// TEL-012 — only Editar/Excluir (this card's scope). Concluir/Reabrir stay hidden entirely,
/// not disabled, per UX-03: they belong to SPEC-010/SPEC-011.
struct TaskDetailView: View {
    @State private var viewModel: TaskDetailViewModel
    let onRequestEdit: () -> Void
    let onDeleted: () -> Void

    /// Owns the view model via `@State` rather than taking a pre-built instance: `NavigationStack`
    /// can invoke this destination's builder more than once for the same push (observed via
    /// XCUITest), and only `@State`'s storage — keyed by this view's identity, not by how many
    /// times `init` runs — survives that so `load()` isn't abandoned mid-flight by a replacement.
    init(taskID: UUID, repository: any TaskRepository, accessToken: String, onRequestEdit: @escaping () -> Void, onDeleted: @escaping () -> Void) {
        _viewModel = State(initialValue: TaskDetailViewModel(taskID: taskID, repository: repository, accessToken: accessToken))
        self.onRequestEdit = onRequestEdit
        self.onDeleted = onDeleted
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.loadFailed {
                ContentUnavailableView {
                    Label("tasks.detail.load_error", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Tentar novamente") { Task { await viewModel.load() } }
                }
            } else if let task = viewModel.task {
                content(for: task)
            } else {
                // Keeps the Group's branch always non-empty before `load()` sets `isLoading`.
                Color.clear
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.task != nil {
                    Button("Editar", action: onRequestEdit)
                        .accessibilityIdentifier("tasks.detail.edit")
                }
            }
        }
        .confirmationDialog(
            "tasks.delete.confirm_message",
            isPresented: $viewModel.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) { Task { await viewModel.confirmDelete() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if viewModel.hasPendingSignal {
                Text("tasks.delete.pending_signal_notice")
            }
        }
        .alert(
            "tasks.detail.mission_protected_title",
            isPresented: Binding(
                get: { viewModel.deleteBlock != nil },
                set: { isPresented in if !isPresented { viewModel.dismissDeleteBlock() } }
            )
        ) {
            Button("OK") { viewModel.dismissDeleteBlock() }
        } message: {
            Text(deleteBlockMessageKey)
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                onDeleted()
            }
        }
    }

    @ViewBuilder
    private func content(for task: FamilyTask) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.title3.weight(.semibold))
                    statusBadge(for: task.status)
                }
                .padding(.vertical, 4)
            }

            Section {
                row(label: "tasks.form.weight_label", value: weightLabel(task.weight))
                row(label: "tasks.form.scheduled_date_label", value: task.scheduledDate)
                row(label: "tasks.form.assignees_label", value: assigneeSummary(task))
            }

            if let note = task.note, !note.isEmpty {
                Section("tasks.detail.note_label") {
                    Text(note)
                }
            }

            if let banner = viewModel.banner {
                Section {
                    Text(banner == .loadFailed ? "tasks.detail.load_error" : "tasks.common.error_unavailable")
                        .foregroundStyle(.red)
                }
            }

            Section {
                if viewModel.canDeleteDirectly {
                    Button("Excluir", role: .destructive) { viewModel.requestDelete() }
                        .disabled(viewModel.isDeleting)
                        .accessibilityIdentifier("tasks.detail.delete")
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Excluir")
                            .foregroundStyle(.secondary)
                        Text("tasks.delete.error_already_completed")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("tasks.detail.delete_disabled")
                }
            }
        }
    }

    private var deleteBlockMessageKey: LocalizedStringKey {
        viewModel.deleteBlock == .alreadyCompleted
            ? "tasks.delete.error_already_completed"
            : "tasks.delete.error_mission_protected"
    }

    private func row(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(for status: TaskStatus) -> some View {
        let (key, icon): (LocalizedStringKey, String) = switch status {
        case .pending: ("tasks.detail.status_pending", "circle")
        case .awaitingConfirmation: ("tasks.detail.status_awaiting_confirmation", "clock")
        case .completed: ("tasks.detail.status_completed", "checkmark.circle.fill")
        }
        return Label(key, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func weightLabel(_ weight: EffortWeight) -> String {
        switch weight {
        case .low: String(localized: "tasks.form.weight_option_low")
        case .medium: String(localized: "tasks.form.weight_option_medium")
        case .high: String(localized: "tasks.form.weight_option_high")
        }
    }

    private func assigneeSummary(_ task: FamilyTask) -> String {
        task.assigneeIDs.isEmpty ? String(localized: "tasks.form.assignees_none") : "\(task.assigneeIDs.count)"
    }
}
