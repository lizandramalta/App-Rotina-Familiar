import AuthenticationServices
import SwiftUI
import UIKit

struct EntryView: View {
    let viewModel: EntryViewModel

    @AccessibilityFocusState private var isAppleButtonFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let isPad = proxy.size.width >= 600
            let contentWidth: CGFloat = isPad ? 540 : min(354, proxy.size.width - 48)
            let actionWidth: CGFloat = isPad ? 400 : contentWidth

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 10) {
                    Image("EntryHomeIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isPad ? 210 : 168, height: isPad ? 188 : 150)
                        .accessibilityLabel(Text("access.entry.illustration_label"))

                    Spacer().frame(height: isPad ? 18 : 12)

                    Text("access.entry.title")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Text("access.entry.subtitle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: contentWidth)

                Spacer(minLength: 40)

                VStack(spacing: 16) {
                    if case let .error(feedback) = viewModel.state {
                        InlineFeedback(feedback: feedback)
                    }

                    appleButton
                        .frame(height: isPad ? 50 : 44)
                        .accessibilityFocused($isAppleButtonFocused)

                    Text("access.entry.invite_hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(viewModel.state.isSubmitting ? 0 : 1)
                        .accessibilityHidden(viewModel.state.isSubmitting)
                }
                .frame(width: actionWidth)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: viewModel.state) { _, newState in
            if !newState.isSubmitting {
                isAppleButtonFocused = true
            }
        }
    }

    @ViewBuilder
    private var appleButton: some View {
        if viewModel.state.isSubmitting {
            ZStack {
                Capsule().fill(.black)
                ProgressView()
                    .tint(.white)
            }
            .accessibilityLabel(Text("access.entry.submitting"))
        } else {
            NativeAppleSignInButton {
                Task { await viewModel.signInWithApple() }
            }
        }
    }
}

private struct NativeAppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.cornerRadius = 22
        button.accessibilityIdentifier = "access.entry.apple_button"
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}

private struct InlineFeedback: View {
    let feedback: EntryFeedback

    var body: some View {
        Label {
            Text(messageKey)
                .font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(messageKey))
    }

    private var messageKey: LocalizedStringKey {
        switch feedback {
        case .appleProofInvalid:
            "access.entry.error_apple_proof_invalid"
        case .network:
            "access.common.error_network"
        case .rateLimited:
            "access.entry.error_rate_limited"
        }
    }
}
