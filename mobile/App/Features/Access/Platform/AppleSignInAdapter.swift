@preconcurrency import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class AppleSignInAdapter: NSObject, AppleAuthenticating {
    private var continuation: CheckedContinuation<AppleAuthorizationProof, Error>?
    private var pendingRawNonce: String?
    private var authorizationController: ASAuthorizationController?

    func authorize() async throws -> AppleAuthorizationProof {
        guard continuation == nil else {
            throw AppleAuthenticationError.nativeFailure
        }

        let rawNonce = makeRawNonce()
        pendingRawNonce = rawNonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        request.nonce = sha256(rawNonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller
            controller.performRequests()
        }
    }

    private func makeRawNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func resume(with result: Result<AppleAuthorizationProof, Error>) {
        guard let continuation else {
            return
        }
        self.continuation = nil
        pendingRawNonce = nil
        authorizationController = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInAdapter: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor [weak self] in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                  let rawNonce = self?.pendingRawNonce else {
                self?.resume(with: .failure(AppleAuthenticationError.nativeFailure))
                return
            }
            self?.resume(with: .success(AppleAuthorizationProof(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                rawNonce: rawNonce
            )))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            let authenticationError = error as? ASAuthorizationError
            let outcome: AppleAuthenticationError = authenticationError?.code == .canceled
                ? .cancelled
                : .nativeFailure
            self?.resume(with: .failure(outcome))
        }
    }
}

extension AppleSignInAdapter: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return window
            }
            guard let scene = scenes.first else {
                fatalError("A window scene is required to present Sign in with Apple.")
            }
            return ASPresentationAnchor(windowScene: scene)
        }
    }
}
