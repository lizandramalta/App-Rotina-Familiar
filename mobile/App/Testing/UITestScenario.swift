#if DEBUG
import Foundation
import UIKit

/// Deterministic, backend-free launch scenarios selected with the `UI_TEST_SCENARIO` environment variable.
enum UITestScenario: String {
    case onboarding = "onboarding"
    case onboardingUncertain = "onboarding-uncertain"
    case onboardingPhotoFailure = "onboarding-photo-failure"
    case onboardingInvite = "onboarding-invite"
    case fullFlow = "full-flow"

    static var current: UITestScenario? {
        ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"].flatMap(UITestScenario.init(rawValue:))
    }

    @MainActor
    func makeContainer() -> AppContainer {
        AppContainer(
            accessRepository: UITestAccessRepository(),
            familyRepository: UITestFamilyRepository(scenario: self),
            credentialStore: UITestCredentialStore(),
            installationProofStore: UITestInstallationProof(),
            appleAuthenticator: UITestAppleAuthenticator()
        )
    }

    @MainActor
    func bootstrap(_ sessionStore: AppSessionStore) {
        if self == .fullFlow {
            sessionStore.discardOnboarding()
            return
        }
        if self == .onboardingPhotoFailure {
            // Seeds a restored draft so the photo path runs without driving the system photo picker.
            sessionStore.returnToEntry(preserving: OnboardingDraft(name: "Maria Silva", photo: Self.samplePhoto))
        } else if self == .onboardingInvite {
            let member1 = DraftMember(id: UUID(), name: "Marina Silva", role: .administrator)
            let member2 = DraftMember(id: UUID(), name: "Lucas Silva", role: .kid)
            sessionStore.returnToEntry(preserving: OnboardingDraft(name: "João Silva", familyName: "Família Silva", members: [member1, member2]))
            sessionStore.apply(.creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture)))
            sessionStore.establishOnboardingSession(AuthenticatedSession(
                sessionID: UUID(),
                profile: ActiveFamilySession(
                    memberID: UUID(),
                    familyID: UUID(),
                    role: .administrator,
                    isFamilyCreator: true
                ),
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                    refreshToken: "ui-test-refresh"
                )
            ))
            return
        }
        sessionStore.apply(.creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture)))
    }

    private static var samplePhoto: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }
}

private struct UITestAccessRepository: AccessRepository {
    func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
        .creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture))
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        throw AccessError.unavailable
    }

    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        throw AccessError.unavailable
    }

    func revokeSession(accessToken: String) async throws {}
}

private actor UITestFamilyRepository: FamilyRepository {
    private let scenario: UITestScenario
    private var photoUploadAttempts = 0

    init(scenario: UITestScenario) {
        self.scenario = scenario
    }

    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily {
        if scenario == .onboardingUncertain {
            throw FamilyError.uncertainOutcome
        }
        let familyID = UUID()
        let memberID = UUID()
        return CreatedFamily(
            familyID: familyID,
            name: command.familyName,
            timeZoneID: command.timeZoneID,
            session: AuthenticatedSession(
                sessionID: UUID(),
                profile: ActiveFamilySession(
                    memberID: memberID,
                    familyID: familyID,
                    role: .administrator,
                    isFamilyCreator: true
                ),
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                    refreshToken: "ui-test-refresh"
                )
            )
        )
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        photoUploadAttempts += 1
        if scenario == .onboardingPhotoFailure, photoUploadAttempts == 1 {
            throw FamilyError.unavailable
        }
        return "ui-test-media"
    }

    func setProfilePhoto(mediaID: String, accessToken: String) async throws {}

    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        CreatedMember(id: UUID(), name: name, role: role)
    }

    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        MemberInvite(inviteID: UUID(), link: "https://example.invalid/invite/test", password: "ABC-123")
    }
}

private final class UITestCredentialStore: SessionCredentialStoring, @unchecked Sendable {
    private var token: String?

    func refreshToken() throws -> String? { token }
    func save(refreshToken: String) throws { token = refreshToken }
    func clear() throws { token = nil }
}

private struct UITestInstallationProof: InstallationProofProviding {
    func installationProof() throws -> String { "ui-test-installation" }
}

@MainActor
private final class UITestAppleAuthenticator: AppleAuthenticating {
    func authorize() async throws -> AppleAuthorizationProof {
        AppleAuthorizationProof(
            identityToken: "ui-test-identity-token",
            authorizationCode: "ui-test-auth-code",
            rawNonce: "ui-test-nonce"
        )
    }
}
#endif
