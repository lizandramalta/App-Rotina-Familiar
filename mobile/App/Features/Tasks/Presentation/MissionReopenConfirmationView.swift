import SwiftUI

/// MOD-006 — shown only on `409 MISSION_REOPEN_REQUIRES_CONFIRMATION` (SPEC-011 E-01); the mobile
/// never pre-calculates mission impact. Role-aware copy per UX-011 §3 (simplified wording for Kids,
/// never mentioning "recompensa" when `hasAcceptedReward` is `false`).
struct MissionReopenConfirmationView: View {
    let prompt: MissionReopenPrompt
    let role: MemberRole
    let isSubmitting: Bool
    var isWarningFocused: AccessibilityFocusState<Bool>.Binding
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var isKids: Bool { role == .kid }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text(isKids ? "task.reopen.mission_warning_title_kids" : "task.reopen.mission_warning_title")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(isWarningFocused)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(prompt.missionsAffected) { mission in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(missionBody(for: mission))
                        }
                    }

                    if prompt.hasAcceptedReward {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "gift.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("task.reopen.mission_warning_reward")
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.reopen.cancel_button", action: onCancel)
                        .disabled(isSubmitting)
                        .frame(minWidth: 44, minHeight: isKids ? 56 : 44)
                        .accessibilityIdentifier("task.reopen.mission_warning.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("task.reopen.confirm_button", role: .destructive, action: onConfirm)
                            .frame(minWidth: 44, minHeight: isKids ? 56 : 44)
                            .accessibilityIdentifier("task.reopen.mission_warning.confirm")
                    }
                }
            }
            .task {
                isWarningFocused.wrappedValue = true
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func missionBody(for mission: AffectedMission) -> String {
        let key: String.LocalizationValue = isKids
            ? "task.reopen.mission_warning_body_kids"
            : "task.reopen.mission_warning_body"
        return String(format: String(localized: key), mission.title)
    }
}
