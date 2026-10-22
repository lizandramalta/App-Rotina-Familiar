import Foundation

@MainActor
final class AppContainer {
    private let accessRepository: any AccessRepository
    private let inviteJoinRepository: any InviteJoinRepository
    private let inviteJoinAttemptStore: any InviteJoinAttemptStoring
    private let inviteLinkParser: InviteLinkParser
    private let familyRepository: any FamilyRepository
    private let profileRepository: any ProfileRepository
    private let credentialStore: any SessionCredentialStoring
    private let installationProofStore: any InstallationProofProviding
    private let appleAuthenticator: any AppleAuthenticating
    private let photoNormalizer: any ProfilePhotoNormalizing

    init(
        accessRepository: any AccessRepository,
        inviteJoinRepository: any InviteJoinRepository,
        inviteJoinAttemptStore: any InviteJoinAttemptStoring,
        inviteLinkParser: InviteLinkParser,
        familyRepository: any FamilyRepository,
        profileRepository: any ProfileRepository,
        credentialStore: any SessionCredentialStoring,
        installationProofStore: any InstallationProofProviding,
        appleAuthenticator: any AppleAuthenticating,
        photoNormalizer: any ProfilePhotoNormalizing = ProfilePhotoNormalizer()
    ) {
        self.accessRepository = accessRepository
        self.inviteJoinRepository = inviteJoinRepository
        self.inviteJoinAttemptStore = inviteJoinAttemptStore
        self.inviteLinkParser = inviteLinkParser
        self.familyRepository = familyRepository
        self.profileRepository = profileRepository
        self.credentialStore = credentialStore
        self.installationProofStore = installationProofStore
        self.appleAuthenticator = appleAuthenticator
        self.photoNormalizer = photoNormalizer
    }

    convenience init(configuration: AppConfiguration) {
        let secrets = KeychainSecretStore()
        self.init(
            accessRepository: HTTPAccessRepository(baseURL: configuration.apiBaseURL),
            inviteJoinRepository: HTTPInviteJoinRepository(baseURL: configuration.apiBaseURL),
            inviteJoinAttemptStore: KeychainInviteJoinAttemptStore(secrets: secrets),
            inviteLinkParser: InviteLinkParser(baseURL: configuration.inviteLinkBaseURL),
            familyRepository: HTTPFamilyRepository(baseURL: configuration.apiBaseURL),
            profileRepository: HTTPProfileRepository(baseURL: configuration.apiBaseURL),
            credentialStore: KeychainSessionCredentialStore(secrets: secrets),
            installationProofStore: KeychainInstallationProofStore(secrets: secrets),
            appleAuthenticator: AppleSignInAdapter()
        )
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

    func makeInviteJoinCoordinator(sessionStore: AppSessionStore) -> InviteJoinCoordinator {
        InviteJoinCoordinator(
            repository: inviteJoinRepository,
            attempts: inviteJoinAttemptStore,
            installationProofProvider: installationProofStore,
            parser: inviteLinkParser,
            sessionStore: sessionStore
        )
    }

    func makeProfileViewModel(session: ActiveFamilySession, sessionStore: AppSessionStore) -> ProfileViewModel {
        ProfileViewModel(
            repository: profileRepository,
            sessionStore: sessionStore,
            session: session,
            photoNormalizer: photoNormalizer
        )
    }

    func makeOnboardingViewModel(
        grant: CreationGrant,
        sessionStore: AppSessionStore
    ) -> InitialOnboardingViewModel {
        InitialOnboardingViewModel(
            grant: grant,
            repository: familyRepository,
            installationProofProvider: installationProofStore,
            photoNormalizer: photoNormalizer,
            sessionStore: sessionStore
        )
    }
}
