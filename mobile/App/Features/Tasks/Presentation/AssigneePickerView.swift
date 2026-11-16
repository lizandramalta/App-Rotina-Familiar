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
                        .tint(Color.App.Text.secondary)
                } else if viewModel.membersLoadFailed {
                    ContentUnavailableView {
                        Label("tasks.detail.load_error", systemImage: "exclamationmark.triangle")
                            .font(.app(.title3))
                            .foregroundStyle(Color.App.Text.primary)
                    } actions: {
                        Button("Tentar novamente") { Task { await viewModel.loadAssigneeCandidatesIfNeeded() } }
                            .font(.app(.subtitleStrong))
                            .foregroundStyle(Color.App.Text.highlight)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.orderedMembers.enumerated()), id: \.element.id) { index, member in
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.App.Border.separator)
                                        .frame(height: 1)
                                        .padding(.leading, Self.separatorInset)
                                }
                                Button {
                                    toggle(member.id)
                                } label: {
                                    row(for: member, isSelected: draftSelection.contains(member.id))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(draftSelection.contains(member.id) ? [.isSelected] : [])
                                .accessibilityIdentifier("tasks.assignee_picker.row.\(member.id.uuidString)")
                            }
                        }
                        .appCard()
                        .padding(.horizontal, AppSpacing.lg)
                        // Prototype spacing: the card starts 8 pt below the bar.
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xxxl)
                    }
                    // A short family list stays still instead of bouncing under the bar.
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.App.Background.app.ignoresSafeArea())
            .navigationTitle("tasks.form.assignees_label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.App.Text.primary)
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
                    .tint(Color.App.Action.primary)
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

    private static let rowMinHeight: CGFloat = 52
    private static let rowVerticalPadding: CGFloat = 10
    private static let avatarDiameter: CGFloat = 32
    /// Small rounded tag corner and side padding; no token is this small (Figma 6 pt).
    private static let tagCornerRadius: CGFloat = 6
    private static let tagHorizontalPadding: CGFloat = 6
    /// The separator starts under the name, not under the avatar (16 + 32 + 12 + 2).
    private static let separatorInset: CGFloat = 62

    private func row(for member: FamilyMember, isSelected: Bool) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Decorative: VoiceOver already reads the name (UX-007 UX-07).
            Text(viewModel.displayName(for: member).prefix(1).uppercased())
                .font(.app(.caption))
                .foregroundStyle(Color.App.Text.secondary)
                .frame(width: Self.avatarDiameter, height: Self.avatarDiameter)
                .background(Color.App.Background.cardHighlight, in: Circle())
                .accessibilityHidden(true)
            Text(viewModel.displayName(for: member))
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.primary)
            if member.role == .kid {
                Text("tasks.assignee_picker.kids_tag")
                    .font(.app(.caption))
                    .foregroundStyle(Color.App.Text.secondary)
                    .padding(.horizontal, Self.tagHorizontalPadding)
                    .padding(.vertical, AppSpacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.tagCornerRadius)
                            .strokeBorder(Color.App.Border.separator, lineWidth: 1.5)
                    )
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.App.Action.primary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.xxl)
        .padding(.vertical, Self.rowVerticalPadding)
        .frame(minHeight: Self.rowMinHeight)
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
