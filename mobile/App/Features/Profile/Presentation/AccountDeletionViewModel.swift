import Foundation
import Observation

/// TEL-058 — Excluir conta (SPEC-022, UX-022 §5.2/§6). The deletion is immediate and irreversible;
/// only a server confirmation (or a lost-response reconciliation) leaves the screen.
@MainActor
@Observable
final class AccountDeletionViewModel {
    enum Variant: Equatable {
        case member
        case creator(familyName: String)
        case kids
    }

    enum Failure: Equatable {
        /// The deletion was not applied; trying again is safe.
        case generic
        /// The Apple proof was refused (CA-11).
        case apple
        /// The device is offline or the server could not be reached.
        case network
    }

    enum State: Equatable {
        case content
        case submitting
        /// Lost response: checking whether the session still exists before offering a retry (CA-08).
        case confirming
        case failed(Failure)
    }

    let variant: Variant
    private let sessionStore: AppSessionStore
    private let appleAuthenticator: (any AppleAuthenticating)?

    private(set) var state: State = .content
    /// Creator confirmation text (UX-022 UX-01); compared only on the device.
    var typedFamilyName = ""
    /// MOD-015 is presented while this is set.
    var isShowingConfirmation = false

    init(variant: Variant, sessionStore: AppSessionStore, appleAuthenticator: (any AppleAuthenticating)?) {
        self.variant = variant
        self.sessionStore = sessionStore
        self.appleAuthenticator = appleAuthenticator
    }

    var isBusy: Bool { state == .submitting || state == .confirming }

    /// The creator must type the family name exactly (trimmed, case- and accent-sensitive).
    var canRequestDeletion: Bool {
        guard !isBusy else { return false }
        if case let .creator(familyName) = variant {
            return typedFamilyName.trimmingCharacters(in: .whitespacesAndNewlines) == familyName
        }
        return true
    }

    func requestDeletion() {
        guard canRequestDeletion else { return }
        isShowingConfirmation = true
    }

    /// Confirmed in MOD-015.
    func confirmDeletion() async {
        guard !isBusy else { return }
        isShowingConfirmation = false
        state = .submitting
        await send(appleProof: nil)
    }

    private func send(appleProof: AppleAuthorizationProof?) async {
        do {
            try await sessionStore.deleteOwnAccount(appleProof: appleProof)
            // AppSessionStore already replaced the root with TEL-001 (CA-09).
        } catch AccessError.appleProofRequired {
            await reauthenticateWithApple()
        } catch AccessError.appleProofInvalid {
            state = .failed(.apple)
        } catch AccessError.sessionRevoked, AccessError.sessionExpired {
            // Revoked by someone else meanwhile (removal or family deletion): neutral notice (CA-20).
            sessionStore.endRevokedSession()
        } catch {
            await reconcileUncertainOutcome()
        }
    }

    /// SPEC-022 CA-10: a creator without a stored Apple token proves the identity once more.
    private func reauthenticateWithApple() async {
        guard case .creator = variant, let appleAuthenticator else {
            state = .failed(.generic)
            return
        }
        do {
            let proof = try await appleAuthenticator.authorize()
            await send(appleProof: proof)
        } catch is AppleAuthenticationError {
            // Cancelling the Apple sheet returns to the screen without an error (UX-022 §4).
            state = .content
        } catch {
            state = .failed(.apple)
        }
    }

    /// Never resends automatically: asks the server whether the session still exists (RNF12).
    private func reconcileUncertainOutcome() async {
        state = .confirming
        switch await sessionStore.isSessionStillActive() {
        case .some(false):
            sessionStore.completeAccountDeletion()
        case .some(true):
            state = .failed(.generic)
        case .none:
            state = .failed(.network)
        }
    }
}

/// Identity-based, so `navigationDestination(item:)` can push TEL-058 from TEL-030.
extension AccountDeletionViewModel: Hashable {
    nonisolated static func == (lhs: AccountDeletionViewModel, rhs: AccountDeletionViewModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
