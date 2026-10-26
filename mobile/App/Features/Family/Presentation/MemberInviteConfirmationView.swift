import SwiftUI
import UIKit

/// TEL-034 — Confirmação consciente de reemissão de convite (Figma nodes 170:979, 311:2577, 311:2639; UX-004 §5.2).
/// Shares the view model of TEL-032 so the transient credentials never leave memory owned by it.
struct MemberInviteConfirmationView: View {
    let viewModel: MemberDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.inviteFailure == .unavailable {
                    ContentUnavailableView {
                        Label("memberInvite.unavailable.title", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("memberInvite.error.unavailable")
                    } actions: {
                        backButton
                    }
                    .accessibilityIdentifier("memberInvite.unavailable")
                } else {
                    if let detail = viewModel.detail {
                        member(detail)
                    }
                    effectsNotice
                    if let message = viewModel.inviteErrorMessage {
                        Label {
                            Text(message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("memberInvite.error")
                    }
                    actions
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("memberInvite.reissue.title")
        .navigationBarTitleDisplayMode(.inline)
        .inviteShareSheet(viewModel: viewModel, isPresented: viewModel.transientInvite != nil)
        .onChange(of: viewModel.transientInvite != nil) { wasShowing, isShowing in
            // The sheet closed: the credentials are gone, so return to TEL-032 (UX-004 §4).
            if wasShowing, !isShowing { dismiss() }
        }
        .onDisappear { viewModel.clearInviteFailure() }
    }

    private func member(_ detail: FamilyMemberDetail) -> some View {
        VStack(spacing: 12) {
            Text(String(detail.name.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 80, height: 80)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .accessibilityHidden(true)
            Text(detail.name)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            Text(detail.role.onboardingTitleKey)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("memberInvite.member")
    }

    private var effectsNotice: some View {
        Label {
            Text("memberInvite.confirm.effects")
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.callout)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("memberInvite.effects")
    }

    @ViewBuilder
    private var actions: some View {
        if viewModel.inviteFailure == .uncertain {
            // Nothing is confirmed: go back and start over from TEL-032 (CA-07).
            backButton
        } else {
            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.confirmReissue() }
                } label: {
                    if viewModel.isIssuingInvite {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("memberInvite.submitting")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text("memberInvite.reissue.action")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isIssuingInvite)
                .accessibilityHint("memberInvite.a11y.action_hint")
                .accessibilityIdentifier("memberInvite.reissue.action")

                Button("memberInvite.cancel.action") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(viewModel.isIssuingInvite)
                    .accessibilityIdentifier("memberInvite.cancel.action")
            }
        }
    }

    private var backButton: some View {
        Button("memberInvite.back.action") { dismiss() }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityIdentifier("memberInvite.back.action")
    }
}

extension View {
    /// Presents the system share sheet with the single invite message. Closing it, completed or not, hands control
    /// back to the view model, which drops the credentials (SPEC-004 CA-08).
    func inviteShareSheet(viewModel: MemberDetailViewModel, isPresented: Bool) -> some View {
        background {
            InviteSharePresenter(message: isPresented ? viewModel.shareMessage : nil) { completed in
                viewModel.onShareDismissed(completed: completed)
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
}

/// Presents `UIActivityViewController` from UIKit so its own completion handler reports every dismissal
/// (iPhone sheet, iPad popover). The message lives only as long as the view model keeps the credentials.
private struct InviteSharePresenter: UIViewControllerRepresentable {
    let message: String?
    let onFinish: @MainActor (Bool) -> Void

    final class Coordinator {
        var isPresenting = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        let coordinator = context.coordinator
        guard let message, !coordinator.isPresenting, let root = host.view.window?.rootViewController else { return }

        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }

        let controller = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in
                onFinish(completed)
                coordinator.isPresenting = false
            }
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        coordinator.isPresenting = true
        presenter.present(controller, animated: true)
    }
}
