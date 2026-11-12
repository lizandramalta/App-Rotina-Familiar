import SwiftUI
import UIKit

/// Presents the system share sheet with the single invite message (SPEC-004 CA-08; UX-004 §5.2).
///
/// TEL-034: shared by TEL-056 (onboarding) and TEL-032 (member detail); every issuance opens it directly (UX-004 UX-07). It presents from UIKit so the activity
/// controller's own completion reports every dismissal (iPhone sheet, iPad popover). When another controller is
/// still being presented or dismissed (an alert closing, for example), it waits for that transition instead of
/// dropping the presentation (SCRUM-114). If it still cannot present, it reports a non-completed dismissal so the
/// caller drops the credentials and never stays stuck.
struct InviteSharePresenter: UIViewControllerRepresentable {
    /// Message with link and password; `nil` while there is nothing to share.
    let message: String?
    let onFinish: @MainActor (_ completed: Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.onFinish = onFinish
        guard let message, !coordinator.isPresenting else { return }
        coordinator.isPresenting = true
        DispatchQueue.main.async { [weak host] in
            guard let host else {
                coordinator.finish(completed: false)
                return
            }
            coordinator.present(message, from: host, attempt: 0)
        }
    }

    @MainActor
    final class Coordinator {
        /// Retries while the host has no window or a transition has no coordinator: about two seconds in total.
        private static let maxAttempts = 20
        private static let retryDelay: TimeInterval = 0.1

        var isPresenting = false
        var onFinish: (@MainActor (Bool) -> Void)?

        func present(_ message: String, from host: UIViewController, attempt: Int) {
            guard let root = host.view.window?.rootViewController else {
                retry(message, from: host, attempt: attempt)
                return
            }

            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            if presenter.isBeingPresented || presenter.isBeingDismissed {
                if let transition = presenter.transitionCoordinator {
                    transition.animate(alongsideTransition: nil) { [weak self, weak host] _ in
                        guard let self, let host else { return }
                        self.present(message, from: host, attempt: attempt + 1)
                    }
                } else {
                    retry(message, from: host, attempt: attempt)
                }
                return
            }

            let controller = UIActivityViewController(activityItems: [message], applicationActivities: nil)
            controller.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                Task { @MainActor in self?.finish(completed: completed) }
            }
            if let popover = controller.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            presenter.present(controller, animated: true)
        }

        func finish(completed: Bool) {
            guard isPresenting else { return }
            isPresenting = false
            onFinish?(completed)
        }

        private func retry(_ message: String, from host: UIViewController, attempt: Int) {
            guard attempt < Self.maxAttempts else {
                finish(completed: false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self, weak host] in
                guard let self else { return }
                guard let host else {
                    self.finish(completed: false)
                    return
                }
                self.present(message, from: host, attempt: attempt + 1)
            }
        }
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
