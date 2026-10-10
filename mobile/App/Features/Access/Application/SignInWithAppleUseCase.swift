import Foundation

struct SignInWithAppleUseCase: Sendable {
    private let repository: any AccessRepository
    private let installationProofProvider: any InstallationProofProviding

    init(
        repository: any AccessRepository,
        installationProofProvider: any InstallationProofProviding
    ) {
        self.repository = repository
        self.installationProofProvider = installationProofProvider
    }

    func execute(_ proof: AppleAuthorizationProof) async throws -> AppleSignInOutcome {
        let installationProof = try installationProofProvider.installationProof()
        return try await repository.signIn(proof: proof, installationProof: installationProof)
    }
}
