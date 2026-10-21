import SwiftUI

extension View {
    /// Keeps onboarding forms in a centered column on iPad (UX-002 §8).
    func onboardingColumn() -> some View {
        modifier(OnboardingColumnModifier())
    }
}

private struct OnboardingColumnModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? 560 : .infinity)
            .frame(maxWidth: .infinity)
    }
}

struct FieldErrorText: View {
    let key: LocalizedStringKey
    let identifier: String

    var body: some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.footnote)
        .foregroundStyle(.red)
        .accessibilityIdentifier(identifier)
    }
}

struct OnboardingPrimaryButton: View {
    let title: LocalizedStringKey
    let identifier: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onboardingColumn()
        .background(.bar)
    }
}

extension MemberRole {
    var onboardingTitleKey: LocalizedStringKey {
        switch self {
        case .administrator: "family.member.role.administrator"
        case .member: "family.member.role.member"
        case .kid: "family.member.role.kids"
        }
    }
}

struct RoleBadge: View {
    let role: MemberRole

    var body: some View {
        Text(role.onboardingTitleKey)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}
