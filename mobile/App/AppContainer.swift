import Foundation

@MainActor
final class AppContainer {
    private let accessRepository: any AccessRepository
    private let credentialStore: any SessionCredentialStoring
    private let installationProofStore: any InstallationProofProviding
    private let appleAuthenticator: any AppleAuthenticating

    init(configuration: AppConfiguration) {
        let secrets = KeychainSecretStore()
        accessRepository = HTTPAccessRepository(baseURL: configuration.apiBaseURL)
        credentialStore = KeychainSessionCredentialStore(secrets: secrets)
        installationProofStore = KeychainInstallationProofStore(secrets: secrets)
        appleAuthenticator = AppleSignInAdapter()
    }

    func makeSessionStore() -> AppSessionStore {
        AppSessionStore(
            repository: accessRepository,
            credentialStore: credentialStore,
            installationProofProvider: installationProofStore
        )
    }

    func makeEntryViewModel(sessionStore: AppSessionStore) -> EntryViewModel {
        EntryViewModel(
            appleAuthenticator: appleAuthenticator,
            signIn: SignInWithAppleUseCase(
                repository: accessRepository,
                installationProofProvider: installationProofStore
            ),
            sessionStore: sessionStore
        )
    }
}
