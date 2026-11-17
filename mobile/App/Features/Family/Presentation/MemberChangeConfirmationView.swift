import SwiftUI

/// MOD-010 — Confirmar alteração de membro (UX-003 §5.4; Figma 870:25368).
/// Shows the member, the change and its effects; nothing is saved until Confirmar/Remover.
/// The caller runs the operation and keeps the sheet open on failure so the error stays in context.
struct MemberChangeConfirmationView: View {
    enum Change: Identifiable, Equatable {
        case role(MemberRole)
        case remove

        var id: String {
            switch self {
            case let .role(role): "role.\(role.rawValue)"
            case .remove: "remove"
            }
        }

        var titleKey: LocalizedStringKey {
            switch self {
            case .role: "family.members.role_change.title"
            case .remove: "family.members.remove.title"
            }
        }

        var effectKey: LocalizedStringKey {
            switch self {
            case .role: "family.member.manage.role_confirm_message"
            case .remove: "family.members.remove.message"
            }
        }

        var confirmKey: LocalizedStringKey {
            switch self {
            case .role: "family.members.change.confirm_action"
            case .remove: "family.members.change.remove_action"
            }
        }

        var progressKey: LocalizedStringKey {
            switch self {
            case .role: "family.members.change.saving"
            case .remove: "family.members.change.removing"
            }
        }

        var isDestructive: Bool { self == .remove }
    }

    let change: Change
    let memberName: String
    let memberColor: Color
    let currentRole: MemberRole
    let isSubmitting: Bool
    let showsError: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text(change.titleKey)
                        .font(.app(.title3))
                        .foregroundStyle(Color.App.Text.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                        .accessibilityIdentifier("family.member.change.title")
                    summaryCard
                    FamilyNoticeCard(change.effectKey)
                        .accessibilityIdentifier("family.member.change.effect")
                    if showsError {
                        FamilyNoticeCard("family.member.manage.error", tone: .error)
                            .accessibilityAddTraits(.isStaticText)
                            .accessibilityIdentifier("family.member.change.error")
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xxxl)
                .padding(.bottom, AppSpacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
        }
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .background(Color.App.Background.app.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting)
        .onAppear { isTitleFocused = true }
    }

    private var summaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            MemberAvatarView(name: memberName, color: memberColor, size: 40)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(memberName)
                    .font(.app(.bodyStrong))
                    .foregroundStyle(Color.App.Text.primary)
                switch change {
                case let .role(newRole):
                    HStack(spacing: AppSpacing.xs) {
                        Text(currentRole.onboardingTitleKey)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(newRole.onboardingTitleKey)
                            .fontWeight(.bold)
                    }
                    .font(.app(.subtitle))
                    .foregroundStyle(Color.App.Text.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(
                        format: String(localized: "family.members.change.role_transition"),
                        currentRole.localizedTitle,
                        newRole.localizedTitle
                    ))
                case .remove:
                    Text(currentRole.onboardingTitleKey)
                        .font(.app(.subtitle))
                        .foregroundStyle(Color.App.Text.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .appCard(cornerRadius: AppRadius.pill)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("family.member.change.summary")
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button(role: change.isDestructive ? .destructive : nil, action: onConfirm) {
                HStack(spacing: AppSpacing.sm) {
                    if isSubmitting {
                        ProgressView().tint(Color.App.Text.onAction)
                    }
                    Text(isSubmitting ? change.progressKey : change.confirmKey)
                }
            }
            .buttonStyle(confirmStyle)
            .disabled(isSubmitting)
            .accessibilityIdentifier("family.member.change.confirm")

            Button("family.settings.hub.cancel", action: onCancel)
                .font(.app(.bodyStrong))
                .foregroundStyle(Color.App.Text.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(isSubmitting)
                .accessibilityIdentifier("family.member.change.cancel")
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.lg)
    }

    /// Both confirmations use the olive primary pill (Figma 870:25406): no red. The "Remover" label and the
    /// destructive role still tell removal apart, never color alone.
    private var confirmStyle: AppPillButtonStyle { AppPillButtonStyle(kind: .primary) }
}

private extension MemberRole {
    var localizedTitle: String {
        switch self {
        case .administrator: String(localized: "family.member.role.administrator")
        case .member: String(localized: "family.member.role.member")
        case .kid: String(localized: "family.member.role.kids")
        }
    }
}
