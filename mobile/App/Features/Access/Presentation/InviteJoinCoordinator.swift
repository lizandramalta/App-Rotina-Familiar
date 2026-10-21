import Foundation
import Observation
import Security

enum InviteJoinScreenState: Equatable {
    case inspecting
    case password
    case submitting
    case invalidPassword
    case unavailable
    case rateLimited
    case recovering
    case recoveryRetryable
    case recoveryUnavailable
    case help
    case networkFailure

    var blocksDismissal: Bool {
        self == .submitting || self == .recovering || self == .recoveryRetryable
    }
}

@MainActor
@Observable
final class InviteJoinCoordinator {
    private let repository: any InviteJoinRepository
    private let attempts: any InviteJoinAttemptStoring
    private let installationProofProvider: any InstallationProofProviding
    private let parser: InviteLinkParser
    private let sessionStore: AppSessionStore

    private var token: String?
    private var pendingLinkToken: String?
    private var switchConfirmed = false
    private var generation = 0

    var password = ""
    var screen: InviteJoinScreenState = .inspecting
    var isPresented = false
    var showsSwitchConfirmation = false

    init(
        repository: any InviteJoinRepository,
        attempts: any InviteJoinAttemptStoring,
        installationProofProvider: any InstallationProofProviding,
        parser: InviteLinkParser,
        sessionStore: AppSessionStore
    ) {
        self.repository = repository
        self.attempts = attempts
        self.installationProofProvider = installationProofProvider
        self.parser = parser
        self.sessionStore = sessionStore
    }

    func open(_ url: URL) async {
        guard let parsedToken = parser.token(from: url) else {
            return
        }
        if case .restoring = sessionStore.state {
            pendingLinkToken = parsedToken
            return
        }
        if screen.blocksDismissal, isPresented {
            pendingLinkToken = parsedToken
            return
        }
        await begin(parsedToken)
    }

    func handleRestoredState() async {
        guard let pendingLinkToken else { return }
        if case .restoring = sessionStore.state { return }
        guard !isPresented || !screen.blocksDismissal else { return }
        self.pendingLinkToken = nil
        await begin(pendingLinkToken)
    }

    private func begin(_ newToken: String) async {
        generation += 1
        token = newToken
        password = ""
        isPresented = false
        switchConfirmed = false
        if case .authenticated = sessionStore.state {
            showsSwitchConfirmation = true
        } else {
            await inspect()
        }
    }

    func confirmSwitch() async {
        showsSwitchConfirmation = false
        switchConfirmed = true
        await inspect()
    }

    func cancelSwitch() {
        showsSwitchConfirmation = false
        token = nil
        switchConfirmed = false
        generation += 1
    }

    func inspect() async {
        guard let token else { return }
        let currentGeneration = generation
        screen = .inspecting
        isPresented = true
        do {
            try await repository.inspect(token: token)
            guard generation == currentGeneration else { return }
            screen = .password
        } catch let error as InviteJoinError {
            guard generation == currentGeneration else { return }
            switch error {
            case .inviteUnavailable: screen = .unavailable
            case .rateLimited: screen = .rateLimited
            default: screen = .networkFailure
            }
        } catch {
            guard generation == currentGeneration else { return }
            screen = .networkFailure
        }
    }

    func submit() async {
        guard let token, !password.isEmpty,
              screen == .password || screen == .invalidPassword else { return }
        let currentGeneration = generation
        screen = .submitting
        let attempt: InviteJoinAttempt
        let previousAccessToken: String?
        do {
            let proof = try installationProofProvider.installationProof()
            attempt = try Self.makeAttempt(installationProof: proof)
            previousAccessToken = switchConfirmed ? try await sessionStore.accessTokenForConfirmedSwitch() : nil
            guard generation == currentGeneration else { return }
            try attempts.save(attempt)
        } catch {
            guard generation == currentGeneration else { return }
            screen = .networkFailure
            return
        }

        do {
            let session = try await repository.join(
                token: token,
                password: password,
                attempt: attempt,
                switchConfirmed: switchConfirmed,
                previousAccessToken: previousAccessToken
            )
            guard generation == currentGeneration else { return }
            try install(session)
        } catch let error as InviteJoinError {
            guard generation == currentGeneration else { return }
            switch error {
            case .network, .resultUncertain:
                await recover(attempt: attempt)
            case .invalidPassword:
                try? attempts.clear()
                screen = .invalidPassword
            case .inviteUnavailable:
                try? attempts.clear()
                screen = .unavailable
            case .rateLimited:
                try? attempts.clear()
                screen = .rateLimited
            default:
                try? attempts.clear()
                screen = .networkFailure
            }
        } catch {
            guard generation == currentGeneration else { return }
            // A session result may have been received while Keychain was unavailable.
            // Preserve the proof and retry only recovery, never the join command.
            screen = .recoveryRetryable
        }
    }

    func retryRecovery() async {
        guard let attempt = try? attempts.pendingAttempt() else {
            screen = .recoveryUnavailable
            return
        }
        await recover(attempt: attempt)
    }

    private func recover(attempt: InviteJoinAttempt) async {
        screen = .recovering
        isPresented = true
        let currentGeneration = generation
        do {
            let session = try await repository.recover(attempt: attempt)
            guard generation == currentGeneration else { return }
            try install(session)
        } catch let error as InviteJoinError {
            guard generation == currentGeneration else { return }
            if error == .recoveryUnavailable {
                try? attempts.clear()
                screen = .recoveryUnavailable
            } else {
                screen = .recoveryRetryable
            }
        } catch {
            guard generation == currentGeneration else { return }
            screen = .recoveryRetryable
        }
    }

    /// Returns true when startup found a pending attempt and handled the initial route.
    func resumePendingAttempt() async -> Bool {
        guard let attempt = try? attempts.pendingAttempt() else { return false }
        await recover(attempt: attempt)
        if case .authenticated = sessionStore.state { return true }
        await sessionStore.restore()
        return true
    }

    func showHelp() {
        screen = .help
        password = ""
    }

    func close() {
        guard !screen.blocksDismissal else { return }
        generation += 1
        token = nil
        password = ""
        switchConfirmed = false
        isPresented = false
        Task { await handleRestoredState() }
    }

    private func install(_ session: AuthenticatedSession) throws {
        try sessionStore.applyInviteSession(session)
        try? attempts.clear()
        password = ""
        token = nil
        switchConfirmed = false
        isPresented = false
        Task { await handleRestoredState() }
    }

    private static func makeAttempt(installationProof: String) throws -> InviteJoinAttempt {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw KeychainSecretStoreError.invalidValue
        }
        return InviteJoinAttempt(
            id: UUID(),
            secret: Data(bytes).base64EncodedString(),
            installationProof: installationProof
        )
    }
}
