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

    private static let iconDiameter: CGFloat = 52

    private var buttonHeight: CGFloat {
        isKids ? AppPillButtonStyle.kidsHeight : AppPillButtonStyle.height
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.app(.title2))
                    .foregroundStyle(Color.App.Action.primary)
                    .frame(width: Self.iconDiameter, height: Self.iconDiameter)
                    .background(Color.App.Background.cardHighlight, in: Circle())
                    .accessibilityHidden(true)

                Text(isKids ? "task.reopen.mission_warning_title_kids" : "task.reopen.mission_warning_title")
                    .font(.app(.title2))
                    .foregroundStyle(Color.App.Text.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(isWarningFocused)

                impacts

                VStack(spacing: AppSpacing.md) {
                    Button(role: .destructive, action: onConfirm) {
                        HStack(spacing: AppSpacing.sm) {
                            if isSubmitting {
                                ProgressView().tint(Color.App.Text.primary)
                            }
                            Text("task.reopen.confirm_button")
                        }
                    }
                    .buttonStyle(AppPillButtonStyle(
                        kind: .highlight,
                        height: buttonHeight,
                        foreground: Color.App.Text.primary,
                        font: .app(.body)
                    ))
                    .accessibilityIdentifier("task.reopen.mission_warning.confirm")

                    Button("task.reopen.cancel_button", role: .cancel, action: onCancel)
                        .buttonStyle(AppPillButtonStyle(kind: .highlight, height: buttonHeight))
                        .accessibilityIdentifier("task.reopen.mission_warning.cancel")
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.giant)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Figma 907:24022: white sheet surface.
        .presentationBackground(Color.App.Background.card)
        .task {
            isWarningFocused.wrappedValue = true
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
    }

    private var impacts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(prompt.missionsAffected) { mission in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "flag.fill")
                        .accessibilityHidden(true)
                    Text(missionBody(for: mission))
                }
            }

            if prompt.hasAcceptedReward {
                Rectangle()
                    .fill(Color.App.Border.separator)
                    .frame(height: 1)
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "gift.fill")
                        .accessibilityHidden(true)
                    Text("task.reopen.mission_warning_reward")
                }
            }
        }
        .font(.app(.subtitle))
        .foregroundStyle(Color.App.Text.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        // Figma 907:24030: flat app-background box, no card stroke or shadow.
        .background(Color.App.Background.app, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func missionBody(for mission: AffectedMission) -> String {
        let key: String.LocalizationValue = isKids
            ? "task.reopen.mission_warning_body_kids"
            : "task.reopen.mission_warning_body"
        return String(format: String(localized: key), mission.title)
    }
}
