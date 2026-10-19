import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct InitialOnboardingViewModelTests {
    private let grant = CreationGrant(value: "grant-1", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))

    // MARK: Navigation and draft (TEL-055 / TEL-002)

    @Test("SPEC-002 CA-02 blocks TEL-055 continuation without a valid name")
    func continueRequiresName() {
        let harness = Harness()

        harness.viewModel.continueFromProfile()
        #expect(harness.viewModel.path.isEmpty)
        #expect(harness.viewModel.nameError == .required)

        harness.viewModel.name = "Ana\nSilva"
        harness.viewModel.continueFromProfile()
        #expect(harness.viewModel.nameError == .invalid)

        harness.viewModel.name = "Ana"
        harness.viewModel.nickname = String(repeating: "x", count: 21)
        harness.viewModel.continueFromProfile()
        #expect(harness.viewModel.nicknameError)
        #expect(harness.viewModel.path.isEmpty)
    }

    @Test("SPEC-002 CA-09 going back from TEL-002 to TEL-055 preserves the draft")
    func backPreservesDraft() {
        let harness = Harness()
        harness.viewModel.name = "Ana"
        harness.viewModel.nickname = "Mãe"
        harness.viewModel.continueFromProfile()
        harness.viewModel.familyName = "Casa Silva"
        harness.viewModel.timeZoneID = "Europe/Lisbon"

        harness.viewModel.goBackToProfile()

        #expect(harness.viewModel.path.isEmpty)
        #expect(harness.viewModel.name == "Ana")
        #expect(harness.viewModel.nickname == "Mãe")
        #expect(harness.viewModel.familyName == "Casa Silva")
        #expect(harness.viewModel.timeZoneID == "Europe/Lisbon")
    }

    @Test("SPEC-002 CA-10 stores the normalized photo in the draft and allows removing it")
    func photoSelection() async {
        let harness = Harness(normalizer: PhotoNormalizerStub(result: .success(Data([9, 9]))))

        await harness.viewModel.selectPhoto(from: Data([1]))
        #expect(harness.viewModel.photo == Data([9, 9]))

        harness.viewModel.removePhoto()
        #expect(harness.viewModel.photo == nil)
    }

    @Test("SPEC-002 CA-10 reports an unreadable photo without blocking the form")
    func unreadablePhoto() async {
        let harness = Harness(normalizer: PhotoNormalizerStub(result: .failure(ProfilePhotoError.unreadableImage)))

        await harness.viewModel.selectPhoto(from: Data([1]))

        #expect(harness.viewModel.photo == nil)
        #expect(harness.viewModel.photoSelectionFailed)
    }

    @Test("SPEC-002 TEL-033 creates, edits and removes local draft members with validation")
    func memberDraftCRUD() {
        let harness = Harness()

        #expect(harness.viewModel.saveMember(id: nil, name: " ", role: .member) == .required)
        #expect(harness.viewModel.saveMember(id: nil, name: "Pedro\n", role: .member) == .invalidContent)
        #expect(harness.viewModel.members.isEmpty)

        #expect(harness.viewModel.saveMember(id: nil, name: " Pedro ", role: .kid) == nil)
        let created = harness.viewModel.members[0]
        #expect(created.name == "Pedro")
        #expect(created.role == .kid)

        #expect(harness.viewModel.saveMember(id: created.id, name: "Pedro S.", role: .administrator) == nil)
        #expect(harness.viewModel.members.count == 1)
        #expect(harness.viewModel.members[0].name == "Pedro S.")
        #expect(harness.viewModel.members[0].role == .administrator)

        harness.viewModel.removeMember(id: created.id)
        #expect(harness.viewModel.members.isEmpty)
    }

    @Test("SPEC-002 UX-002 discarding clears the draft and returns to TEL-001")
    func discardClearsDraft() {
        let harness = Harness()
        harness.sessionStore.apply(.creationGrant(grant))
        harness.viewModel.name = "Ana"
        harness.viewModel.verifyAccess()
        #expect(harness.sessionStore.onboardingDraft != nil)

        harness.viewModel.discard()

        #expect(harness.sessionStore.state == .entry)
        #expect(harness.sessionStore.onboardingDraft == nil)
    }

    // MARK: Creation (CA-01, CA-04, CA-09)

    @Test("SPEC-002 CA-01 sends trimmed values with the grant and opens the app when there are no members")
    func createWithoutMembersOpensTheApp() async {
        let harness = Harness()
        await harness.fill()

        await harness.viewModel.createFamily()

        let command = await harness.repository.lastCommand
        #expect(command?.creationGrant == "grant-1")
        #expect(command?.creatorName == "Ana")
        #expect(command?.creatorNickname == "Mãe")
        #expect(command?.familyName == "Casa Silva")
        #expect(command?.timeZoneID == "America/Sao_Paulo")
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
        #expect(harness.credentials.savedRefreshToken == "refresh")
        #expect(harness.sessionStore.accessToken == "access")
    }

    @Test("SPEC-002 CA-02 does not call the API when the family name is invalid")
    func invalidFamilyNameDoesNotCallTheAPI() async {
        let harness = Harness()
        await harness.fill(familyName: "   ")

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.familyNameError == .required)
        #expect(await harness.repository.createFamilyCalls == 0)
    }

    @Test("SPEC-002 CA-09 ignores duplicate submissions while one is in flight")
    func duplicateSubmissionIsBlocked() async {
        let harness = Harness(repository: FamilyRepositorySpy(createDelay: .milliseconds(80)))
        await harness.fill()

        async let first: Void = harness.viewModel.createFamily()
        async let second: Void = harness.viewModel.createFamily()
        _ = await (first, second)

        #expect(await harness.repository.createFamilyCalls == 1)
    }

    @Test("SPEC-002 CA-09 keeps the draft and requires verifying access after an uncertain outcome")
    func uncertainOutcomePreservesDraft() async {
        let harness = Harness(repository: FamilyRepositorySpy(createResult: .failure(FamilyError.uncertainOutcome)))
        await harness.fill()
        _ = harness.viewModel.saveMember(id: nil, name: "Pedro", role: .member)

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.banner == .uncertainOutcome)
        #expect(!harness.viewModel.isFamilyCreated)
        #expect(!harness.viewModel.isCreating)
        #expect(harness.credentials.savedRefreshToken == nil)
        #expect(harness.viewModel.familyName == "Casa Silva")

        harness.viewModel.verifyAccess()

        #expect(harness.sessionStore.state == .entry)
        #expect(harness.sessionStore.onboardingDraft == harness.viewModel.draft)
        #expect(await harness.repository.createFamilyCalls == 1)
    }

    @Test("SPEC-002 CA-09 a new creation grant restores the preserved draft")
    func newGrantRestoresDraft() async {
        let harness = Harness(repository: FamilyRepositorySpy(createResult: .failure(FamilyError.uncertainOutcome)))
        await harness.fill()
        _ = harness.viewModel.saveMember(id: nil, name: "Pedro", role: .kid)
        harness.viewModel.timeZoneID = "Europe/Lisbon"
        await harness.viewModel.createFamily()
        harness.viewModel.verifyAccess()

        let newGrant = CreationGrant(value: "grant-2", expiresAt: Date(timeIntervalSince1970: 1_900_000_000))
        harness.sessionStore.apply(.creationGrant(newGrant))
        let restored = InitialOnboardingViewModel(
            grant: newGrant,
            repository: harness.repository,
            installationProofProvider: FamilyInstallationProofStub(),
            photoNormalizer: PhotoNormalizerStub(result: .success(Data())),
            sessionStore: harness.sessionStore
        )

        #expect(harness.sessionStore.state == .initialProfile(newGrant))
        #expect(restored.draft == harness.viewModel.draft)
        #expect(restored.name == " Ana ")
        #expect(restored.familyName == "Casa Silva")
        #expect(restored.timeZoneID == "Europe/Lisbon")
        #expect(restored.members.map(\.name) == ["Pedro"])
    }

    @Test("SPEC-002 CA-09 a family found by a new Apple sign-in discards the draft")
    func discoveredFamilyClearsDraft() {
        let harness = Harness()
        harness.viewModel.name = "Ana"
        harness.viewModel.verifyAccess()

        harness.sessionStore.apply(.session(Harness.session))

        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
        #expect(harness.sessionStore.onboardingDraft == nil)
    }

    @Test("SPEC-002 CA-04 shows a recoverable banner for an invalid grant and never retries")
    func invalidGrant() async {
        let harness = Harness(repository: FamilyRepositorySpy(createResult: .failure(FamilyError.creationGrantInvalid)))
        await harness.fill()

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.banner == .creationGrantInvalid)
        #expect(await harness.repository.createFamilyCalls == 1)
    }

    @Test("SPEC-002 CA-02 maps server field errors back to the right screen and field")
    func serverValidationErrors() async {
        let errors = ["creatorName": ["MEMBER_NAME_INVALID_CONTENT"], "name": ["FAMILY_NAME_INVALID_LENGTH"]]
        let harness = Harness(repository: FamilyRepositorySpy(createResult: .failure(FamilyError.validationFailed(errors))))
        await harness.fill()
        harness.viewModel.continueFromProfile()

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.nameError == .invalid)
        #expect(harness.viewModel.familyNameError == .invalid)
        #expect(harness.viewModel.path.isEmpty)
    }

    @Test("SPEC-002 CA-09 maps rate limiting to a retryable banner")
    func rateLimited() async {
        let harness = Harness(repository: FamilyRepositorySpy(createResult: .failure(FamilyError.rateLimited)))
        await harness.fill()

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.banner == .rateLimited)
        #expect(!harness.viewModel.isFamilyCreated)
    }

    // MARK: Photo after the session (CA-10)

    @Test("SPEC-002 CA-10 uploads and links the photo before leaving onboarding")
    func photoUploadSucceeds() async {
        let harness = Harness(normalizer: PhotoNormalizerStub(result: .success(Data([1, 2, 3]))))
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()

        #expect(await harness.repository.uploadedPhotos == [Data([1, 2, 3])])
        #expect(await harness.repository.linkedMediaIDs == ["media-1"])
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    @Test("SPEC-002 CA-10 keeps the family when the photo fails and retries only the photo")
    func photoFailureThenRetry() async {
        let repository = FamilyRepositorySpy(uploadResults: [.failure(FamilyError.unavailable), .success("media-1")])
        let harness = Harness(repository: repository, normalizer: PhotoNormalizerStub(result: .success(Data([1]))))
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.photoStatus == .failed)
        #expect(harness.viewModel.isFamilyCreated)
        #expect(harness.viewModel.photo == Data([1]))
        #expect(harness.credentials.savedRefreshToken == "refresh")
        #expect(harness.sessionStore.state != .authenticated(Harness.session.profile))

        await harness.viewModel.retryPhoto()

        #expect(harness.viewModel.photoStatus == .idle)
        #expect(await repository.createFamilyCalls == 1)
        #expect(await repository.uploadCalls == 2)
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    @Test("SPEC-002 CA-10 a Keychain failure after 201 keeps the family and the optional photo flow usable")
    func keychainFailureDoesNotAbortPostCreationFlow() async {
        let repository = FamilyRepositorySpy(uploadResults: [.failure(FamilyError.unavailable), .success("media-1")])
        let harness = Harness(repository: repository, normalizer: PhotoNormalizerStub(result: .success(Data([1]))))
        harness.credentials.saveFailuresRemaining = 1
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.isFamilyCreated)
        #expect(harness.viewModel.banner == nil)
        #expect(harness.viewModel.photoStatus == .failed)
        #expect(harness.credentials.savedRefreshToken == nil)

        await harness.viewModel.retryPhoto()

        #expect(await repository.createFamilyCalls == 1)
        #expect(await repository.linkedMediaIDs == ["media-1"])
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
        #expect(harness.credentials.savedRefreshToken == "refresh")
    }

    @Test("SPEC-002 CA-10 a Keychain failure after 201 still allows skipping the photo")
    func keychainFailureThenSkip() async {
        let repository = FamilyRepositorySpy(uploadResults: [.failure(FamilyError.unavailable)])
        let harness = Harness(repository: repository, normalizer: PhotoNormalizerStub(result: .success(Data([1]))))
        harness.credentials.saveFailuresRemaining = 5
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()
        await harness.viewModel.skipPhoto()

        #expect(await repository.createFamilyCalls == 1)
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    @Test("SPEC-002 CA-10 retry after a failed profile PATCH reuses the uploaded media")
    func patchFailureReusesUploadedMedia() async {
        let repository = FamilyRepositorySpy(linkResults: [.failure(FamilyError.unavailable), .success(())])
        let harness = Harness(repository: repository, normalizer: PhotoNormalizerStub(result: .success(Data([1]))))
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()
        #expect(harness.viewModel.photoStatus == .failed)
        await harness.viewModel.retryPhoto()

        #expect(await repository.uploadCalls == 1)
        #expect(await repository.linkedMediaIDs == ["media-1", "media-1"])
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    @Test("SPEC-002 CA-10 skipping the photo continues without calling POST /v1/families again")
    func skipPhoto() async {
        let repository = FamilyRepositorySpy(uploadResults: [.failure(FamilyError.unavailable)])
        let harness = Harness(repository: repository, normalizer: PhotoNormalizerStub(result: .success(Data([1]))))
        await harness.fill(pickingPhoto: true)

        await harness.viewModel.createFamily()
        await harness.viewModel.skipPhoto()

        #expect(await repository.createFamilyCalls == 1)
        #expect(await repository.uploadCalls == 1)
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    // MARK: Hand-off to TEL-056 / TEL-010

    @Test("SPEC-002 CA-11 creates draft members and opens TEL-056 instead of the app")
    func membersRouteToInvites() async {
        let harness = Harness()
        await harness.fill()
        _ = harness.viewModel.saveMember(id: nil, name: "Pedro", role: .member)
        _ = harness.viewModel.saveMember(id: nil, name: "Joana", role: .kid)

        await harness.viewModel.createFamily()

        #expect(harness.viewModel.path == [.family, .inviteMembers])
        #expect(await harness.repository.createdMembers.map(\.name) == ["Pedro", "Joana"])
        #expect(await harness.repository.createdMembers.map(\.role) == [.member, .kid])
        #expect(harness.sessionStore.state != .authenticated(Harness.session.profile))
        #expect(!harness.viewModel.hasPendingMembers)
    }

    @Test("SPEC-002 CA-11 invites are explicit and either button finishes onboarding")
    func inviteThenFinish() async throws {
        let harness = Harness()
        await harness.fill()
        _ = harness.viewModel.saveMember(id: nil, name: "Pedro", role: .member)
        await harness.viewModel.createFamily()
        let draftID = try #require(harness.viewModel.members.first?.id)
        #expect(!harness.viewModel.hasGeneratedInvite)
        #expect(await harness.repository.inviteCalls == 0)

        await harness.viewModel.generateInvite(for: draftID)

        #expect(harness.viewModel.hasGeneratedInvite)
        #expect(harness.viewModel.generatedInvite?.invite.password == "PW")
        harness.viewModel.finishOnboarding()
        #expect(harness.sessionStore.state == .authenticated(Harness.session.profile))
    }

    @Test("SPEC-002 CA-11 a failed member creation stays pending and can be retried explicitly")
    func memberCreationRetry() async {
        let repository = FamilyRepositorySpy(memberResults: [.failure(FamilyError.unavailable)])
        let harness = Harness(repository: repository)
        await harness.fill()
        _ = harness.viewModel.saveMember(id: nil, name: "Pedro", role: .member)

        await harness.viewModel.createFamily()
        #expect(harness.viewModel.path == [.family, .inviteMembers])
        #expect(harness.viewModel.hasPendingMembers)

        await harness.viewModel.retryPendingMembers()

        #expect(!harness.viewModel.hasPendingMembers)
        #expect(await repository.createFamilyCalls == 1)
    }

    // MARK: Harness

    @MainActor
    private final class Harness {
        static let session = AuthenticatedSession(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            profile: ActiveFamilySession(
                memberID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                familyID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                role: .administrator,
                isFamilyCreator: true
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
                refreshToken: "refresh"
            )
        )

        let repository: FamilyRepositorySpy
        let credentials = FamilyCredentialStoreStub()
        let sessionStore: AppSessionStore
        let viewModel: InitialOnboardingViewModel

        init(
            repository: FamilyRepositorySpy = FamilyRepositorySpy(),
            normalizer: PhotoNormalizerStub = PhotoNormalizerStub(result: .success(Data()))
        ) {
            self.repository = repository
            sessionStore = AppSessionStore(
                repository: AccessRepositoryStub(),
                credentialStore: credentials,
                installationProofProvider: FamilyInstallationProofStub()
            )
            viewModel = InitialOnboardingViewModel(
                grant: CreationGrant(value: "grant-1", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
                repository: repository,
                installationProofProvider: FamilyInstallationProofStub(),
                photoNormalizer: normalizer,
                sessionStore: sessionStore
            )
        }

        func fill(familyName: String = "Casa Silva", pickingPhoto: Bool = false) async {
            viewModel.name = " Ana "
            viewModel.nickname = "Mãe"
            viewModel.familyName = familyName
            if pickingPhoto {
                await viewModel.selectPhoto(from: Data([0]))
            }
        }
    }
}
