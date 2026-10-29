import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct OwnProfileEditorViewModelTests {
    // MARK: Initial state and closing

    @Test("initial state: nothing to save and closing does not ask for confirmation")
    func initialState() {
        let harness = Harness()

        #expect(!harness.viewModel.canSave)
        #expect(!harness.viewModel.hasUnsavedChanges)
        #expect(harness.viewModel.name == "Maria Silva")
        #expect(harness.viewModel.nickname == "Mari")

        harness.viewModel.requestClose()

        #expect(!harness.viewModel.isShowingDiscardConfirmation)
        #expect(harness.recorder.dismissCount == 1)
    }

    @Test("closing with unsaved changes asks to discard; confirming dismisses")
    func discardFlow() {
        let harness = Harness()
        harness.viewModel.nickname = "Mi"

        harness.viewModel.requestClose()

        #expect(harness.viewModel.isShowingDiscardConfirmation)
        #expect(harness.recorder.dismissCount == 0)

        harness.viewModel.confirmDiscard()
        #expect(harness.recorder.dismissCount == 1)
    }

    // MARK: Save (CA-02)

    @Test("SPEC-006 CA-02 saves name and nickname, reports the update through onSaved and dismisses")
    func saveSuccess() async {
        let harness = Harness()
        harness.viewModel.name = "  Maria S.  "
        harness.viewModel.nickname = "Mi"
        #expect(harness.viewModel.canSave)

        await harness.viewModel.save()

        let commands = await harness.repository.commands
        #expect(commands == [UpdateOwnProfileCommand(name: "Maria S.", nickname: .set("Mi"), photoMediaID: .unchanged)])
        #expect(harness.recorder.saved.count == 1)
        #expect(harness.recorder.dismissCount == 1)
        #expect(harness.recorder.lastAvatar == nil)
    }

    @Test("only the changed fields are sent; clearing the nickname sends .clear")
    func onlyChangedFields() async {
        let harness = Harness()
        harness.viewModel.nickname = "   "

        await harness.viewModel.save()

        let commands = await harness.repository.commands
        #expect(commands == [UpdateOwnProfileCommand(name: nil, nickname: .clear, photoMediaID: .unchanged)])
    }

    // MARK: Validation (CA-06, CA-13) and Kids (CA-12)

    @Test("SPEC-006 CA-06 internal spaces are allowed up to 20 non-space characters; 21 blocks saving")
    func nicknameLimit() {
        let harness = Harness()
        harness.viewModel.nickname = String(repeating: "a", count: 10) + " " + String(repeating: "b", count: 10)
        #expect(harness.viewModel.nicknameError == nil)
        #expect(harness.viewModel.nicknameNonWhitespaceCount == 20)
        #expect(harness.viewModel.canSave)

        harness.viewModel.nickname = String(repeating: "a", count: 21)
        #expect(harness.viewModel.nicknameError == .invalidLength)
        #expect(!harness.viewModel.canSave)
    }

    @Test("SPEC-006 CA-13 an adult needs a valid name of 1 to 60 characters")
    func adultNameValidation() {
        let harness = Harness()

        harness.viewModel.name = "   "
        #expect(harness.viewModel.nameError == .required)
        #expect(!harness.viewModel.canSave)

        harness.viewModel.name = String(repeating: "a", count: 61)
        #expect(harness.viewModel.nameError == .invalidLength)
        #expect(!harness.viewModel.canSave)

        harness.viewModel.name = "Ana\n"
        #expect(harness.viewModel.nameError == .invalidContent)

        harness.viewModel.name = "Ana"
        #expect(harness.viewModel.nameError == nil)
        #expect(harness.viewModel.canSave)
    }

    @Test("SPEC-006 CA-12 Kids never validate nor send the name")
    func kidsNeverSendName() async {
        let harness = Harness(role: .kid)
        harness.viewModel.name = ""
        harness.viewModel.nickname = "Kid"

        #expect(harness.viewModel.nameError == nil)
        #expect(harness.viewModel.canSave)

        await harness.viewModel.save()

        let commands = await harness.repository.commands
        #expect(commands == [UpdateOwnProfileCommand(name: nil, nickname: .set("Kid"), photoMediaID: .unchanged)])
    }

    @Test("a server NAME_INVALID_LENGTH shows the name error, keeps the form and clears once the name is edited")
    func serverNameRejection() async {
        let harness = Harness(updateResult: .failure(ProfileError.validationFailed(["name": ["NAME_INVALID_LENGTH"]])))
        harness.viewModel.name = "Ana"

        await harness.viewModel.save()

        #expect(harness.viewModel.nameError != nil)
        #expect(harness.viewModel.name == "Ana")
        #expect(harness.recorder.dismissCount == 0)

        harness.viewModel.name = "Ana B"
        #expect(harness.viewModel.nameError == nil)
    }

    @Test("a server NICKNAME_INVALID_LENGTH shows the nickname error")
    func serverNicknameRejection() async {
        let harness = Harness(updateResult: .failure(ProfileError.validationFailed(["nickname": ["NICKNAME_INVALID_LENGTH"]])))
        harness.viewModel.nickname = "Mi"

        await harness.viewModel.save()

        #expect(harness.viewModel.nicknameError != nil)
        #expect(harness.viewModel.nickname == "Mi")
    }

    // MARK: Photo (CA-02, CA-07, CA-08, CA-09)

    @Test("SPEC-006 CA-02 a selected photo is normalized, uploaded and linked on save with the new avatar bytes")
    func photoUploadAndSave() async {
        let harness = Harness(normalized: .success(Data([9, 9])), uploadResults: [.success("media-new")])

        await harness.viewModel.selectPhoto(from: Data([1]))

        #expect(harness.viewModel.currentMediaID == "media-new")
        #expect(harness.viewModel.currentAvatarData == Data([9, 9]))
        #expect(!harness.viewModel.isUploadingPhoto)
        #expect(harness.viewModel.canSave)

        await harness.viewModel.save()

        let commands = await harness.repository.commands
        #expect(commands == [UpdateOwnProfileCommand(photoMediaID: .set("media-new"))])
        #expect(harness.recorder.lastAvatar == .some(Data([9, 9])))
    }

    @Test("cancelling an upload in progress restores the current photo")
    func cancelUpload() async {
        let harness = Harness(uploadResults: [.success("media-new")], uploadDelay: .seconds(30))

        let selecting = Task { await harness.viewModel.selectPhoto(from: Data([1])) }
        while !harness.viewModel.isUploadingPhoto { await Task.yield() }

        harness.viewModel.cancelPhotoUpload()
        await selecting.value

        #expect(!harness.viewModel.isUploadingPhoto)
        #expect(harness.viewModel.currentMediaID == "media-current")
        #expect(harness.viewModel.photoError == nil)
    }

    @Test("cancelling or discarding while the photo is still being normalized never starts an upload")
    func cancelDuringNormalization() async {
        for discard in [false, true] {
            let harness = Harness(normalizeDelay: .seconds(30))

            let selecting = Task { await harness.viewModel.selectPhoto(from: Data([1])) }
            while !harness.viewModel.isUploadingPhoto { await Task.yield() }
            #expect(harness.viewModel.hasUnsavedChanges)

            if discard {
                harness.viewModel.confirmDiscard()
            } else {
                harness.viewModel.cancelPhotoUpload()
            }
            await selecting.value

            #expect(!harness.viewModel.isUploadingPhoto)
            #expect(harness.viewModel.currentMediaID == "media-current")
            #expect(await harness.repository.uploadCalls == 0)
        }
    }

    @Test("SPEC-006 CA-09 an upload failure keeps the current photo; retry succeeds")
    func uploadFailureThenRetry() async {
        let harness = Harness(
            normalized: .success(Data([7])),
            uploadResults: [.failure(ProfileError.network), .success("media-new")]
        )

        await harness.viewModel.selectPhoto(from: Data([1]))

        #expect(harness.viewModel.photoError == .uploadFailed(Data([7])))
        #expect(harness.viewModel.currentMediaID == "media-current")
        #expect(harness.viewModel.currentAvatarData == Data([5]))

        await harness.viewModel.retryPhotoUpload()

        #expect(harness.viewModel.photoError == nil)
        #expect(harness.viewModel.currentMediaID == "media-new")
    }

    @Test("SPEC-006 CA-09 'keep current photo' dismisses the failure without changing anything")
    func keepCurrentPhoto() async {
        let harness = Harness(normalized: .success(Data([7])), uploadResults: [.failure(ProfileError.unavailable)])
        await harness.viewModel.selectPhoto(from: Data([1]))

        harness.viewModel.keepCurrentPhoto()

        #expect(harness.viewModel.photoError == nil)
        #expect(harness.viewModel.currentMediaID == "media-current")
        #expect(!harness.viewModel.hasUnsavedChanges)
    }

    @Test("SPEC-006 CA-08 normalizer refusals map to format and size errors and keep the photo")
    func normalizerErrors() async {
        let unreadable = Harness(normalized: .failure(ProfilePhotoError.unreadableImage))
        await unreadable.viewModel.selectPhoto(from: Data([1]))
        #expect(unreadable.viewModel.photoError == .formatUnsupported)
        #expect(unreadable.viewModel.currentMediaID == "media-current")

        let tooLarge = Harness(normalized: .failure(ProfilePhotoError.tooLarge))
        await tooLarge.viewModel.selectPhoto(from: Data([1]))
        #expect(tooLarge.viewModel.photoError == .tooLarge)
        #expect(tooLarge.viewModel.currentMediaID == "media-current")
    }

    @Test("SPEC-006 CA-08 server 415 and 413 map to format and size errors")
    func serverMediaErrors() async {
        let format = Harness(uploadResults: [.failure(ProfileError.mediaFormatUnsupported)])
        await format.viewModel.selectPhoto(from: Data([1]))
        #expect(format.viewModel.photoError == .formatUnsupported)

        let size = Harness(uploadResults: [.failure(ProfileError.mediaTooLarge)])
        await size.viewModel.selectPhoto(from: Data([1]))
        #expect(size.viewModel.photoError == .tooLarge)
    }

    @Test("SPEC-006 CA-07 PHOTO_MEDIA_NOT_READY on save keeps the form and offers a retry")
    func photoNotReady() async {
        let harness = Harness(
            normalized: .success(Data([7])),
            uploadResults: [.success("media-new")],
            updateResult: .failure(ProfileError.validationFailed(["photoMediaId": ["PHOTO_MEDIA_NOT_READY"]]))
        )
        await harness.viewModel.selectPhoto(from: Data([1]))

        await harness.viewModel.save()

        #expect(harness.viewModel.photoError == .processingNotReady)
        #expect(harness.viewModel.currentMediaID == "media-new")
        #expect(harness.recorder.dismissCount == 0)
    }

    @Test("removing the photo sends .clear and reports the avatar as removed")
    func removePhoto() async {
        let harness = Harness()

        harness.viewModel.removePhoto()
        #expect(harness.viewModel.currentMediaID == nil)
        #expect(harness.viewModel.currentAvatarData == nil)

        await harness.viewModel.save()

        let commands = await harness.repository.commands
        #expect(commands == [UpdateOwnProfileCommand(photoMediaID: .clear)])
        #expect(harness.recorder.lastAvatar == .some(nil))
    }

    // MARK: Network failure (CA-09)

    @Test("SPEC-006 CA-09 a network failure on save shows the banner and preserves what was typed")
    func networkFailurePreservesForm() async {
        let harness = Harness(updateResult: .failure(ProfileError.network))
        harness.viewModel.name = "Ana"
        harness.viewModel.nickname = "Aninha"

        await harness.viewModel.save()

        #expect(harness.viewModel.bannerError == .network)
        #expect(harness.viewModel.name == "Ana")
        #expect(harness.viewModel.nickname == "Aninha")
        #expect(harness.viewModel.canSave)
        #expect(harness.recorder.dismissCount == 0)
        #expect(harness.recorder.saved.isEmpty)
    }

    @Test("a service failure shows the generic banner")
    func unavailableBanner() async {
        let harness = Harness(updateResult: .failure(ProfileError.unavailable))
        harness.viewModel.nickname = "Mi"

        await harness.viewModel.save()

        #expect(harness.viewModel.bannerError == .unavailable)
    }
}

// MARK: - Doubles

@MainActor
private final class Recorder {
    private(set) var saved: [OwnProfile] = []
    private(set) var lastAvatar: Data??
    private(set) var dismissCount = 0

    func didSave(_ profile: OwnProfile, _ avatar: Data??) {
        saved.append(profile)
        lastAvatar = avatar
    }

    func didDismiss() { dismissCount += 1 }
}

private actor EditorRepositorySpy: ProfileRepository {
    private var uploadResults: [Result<String, Error>]
    private let updateResult: Result<OwnProfile, Error>
    private let uploadDelay: Duration?
    private(set) var commands: [UpdateOwnProfileCommand] = []
    private(set) var uploadCalls = 0

    init(uploadResults: [Result<String, Error>], updateResult: Result<OwnProfile, Error>, uploadDelay: Duration?) {
        self.uploadResults = uploadResults
        self.updateResult = updateResult
        self.uploadDelay = uploadDelay
    }

    func getOwnProfile(accessToken: String) async throws -> OwnProfile { try updateResult.get() }

    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile {
        commands.append(command)
        return try updateResult.get()
    }

    func getOwnBadges(accessToken: String) async throws -> BadgesOverview { throw ProfileError.unavailable }
    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail { throw ProfileError.unavailable }
    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data { throw ProfileError.unavailable }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        uploadCalls += 1
        if let uploadDelay {
            try await Task.sleep(for: uploadDelay)
        }
        guard !uploadResults.isEmpty else { return "media-default" }
        return try uploadResults.removeFirst().get()
    }
}

@MainActor
private struct Harness {
    let repository: EditorRepositorySpy
    let recorder = Recorder()
    let viewModel: OwnProfileEditorViewModel

    init(
        role: MemberRole = .member,
        normalized: Result<Data, Error> = .success(Data([1])),
        uploadResults: [Result<String, Error>] = [],
        updateResult: Result<OwnProfile, Error>? = nil,
        uploadDelay: Duration? = nil,
        normalizeDelay: Duration? = nil
    ) {
        let profile = OwnProfile(
            memberID: UUID(),
            name: "Maria Silva",
            familyName: "Família Silva",
            nickname: "Mari",
            photoMediaID: "media-current",
            totalParticipations: 7,
            nextTier: nil
        )
        repository = EditorRepositorySpy(
            uploadResults: uploadResults,
            updateResult: updateResult ?? .success(profile),
            uploadDelay: uploadDelay
        )
        let sessionStore = AppSessionStore(
            repository: AccessRepositoryStub(),
            credentialStore: FamilyCredentialStoreStub(),
            installationProofProvider: FamilyInstallationProofStub()
        )
        sessionStore.apply(.session(AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: role, isFamilyCreator: false),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access-1", expiresAt: .distantFuture),
                refreshToken: "refresh-1"
            )
        )))
        let recorder = recorder
        viewModel = OwnProfileEditorViewModel(
            initialProfile: profile,
            initialAvatarData: Data([5]),
            role: role,
            repository: repository,
            photoNormalizer: SlowNormalizer(result: normalized, delay: normalizeDelay),
            sessionStore: sessionStore,
            onSaved: { recorder.didSave($0, $1) },
            onDismiss: { recorder.didDismiss() }
        )
    }
}

private struct SlowNormalizer: ProfilePhotoNormalizing {
    let result: Result<Data, Error>
    let delay: Duration?

    func normalize(_ data: Data) async throws -> Data {
        if let delay {
            try await Task.sleep(for: delay)
        }
        return try result.get()
    }
}
