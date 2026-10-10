import Foundation
import Observation

enum EntryFeedback: Equatable {
    case appleProofInvalid
    case network
    case rateLimited
}

enum EntryViewState: Equatable {
    case idle
    case submitting
    case error(EntryFeedback)

    var isSubmitting: Bool {
        self == .submitting
    }
}

@MainActor
@Observable
final class EntryViewModel {
    private let appleAuthenticator: any AppleAuthenticating
    private let signIn: SignInWithAppleUseCase
    private let sessionStore: AppSessionStore

    private(set) var state: EntryViewState = .idle

    init(
        appleAuthenticator: any AppleAuthenticating,
        signIn: SignInWithAppleUseCase,
        sessionStore: AppSessionStore
    ) {
        self.appleAuthenticator = appleAuthenticator
        self.signIn = signIn
        self.sessionStore = sessionStore
    }

    func signInWithApple() async {
        guard !state.isSubmitting else {
            return
        }

        do {
            let proof = try await appleAuthenticator.authorize()
            state = .submitting
            let outcome = try await signIn.execute(proof)
            sessionStore.apply(outcome)
            state = .idle
        } catch let error as AppleAuthenticationError {
            switch error {
            case .cancelled, .nativeFailure:
                state = .idle
            }
        } catch let error as AccessError {
            state = switch error {
            case .appleProofInvalid:
                .error(.appleProofInvalid)
            case .rateLimited:
                .error(.rateLimited)
            case .network, .unavailable, .invalidResponse:
                .error(.network)
            case .sessionExpired, .sessionRevoked:
                .error(.network)
            }
        } catch {
            state = .error(.network)
        }
    }
}
