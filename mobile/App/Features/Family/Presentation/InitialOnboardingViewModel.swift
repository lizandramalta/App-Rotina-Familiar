import Foundation
import Observation

enum OnboardingRoute: Hashable {
    case family
    case inviteMembers
}

enum ProfileFieldError: Equatable {
    case required
    case invalid
}

/// Non-blocking feedback on TEL-002 after a failed creation attempt.
enum CreationBanner: Equatable {
    /// CA-04/CA-09: the response was lost; the single-use grant must not be retried.
    case uncertainOutcome
    case creationGrantInvalid
    case rateLimited
    case unavailable
}

enum PhotoStatus: Equatable {
    case idle
    case uploading
    case failed
}

/// Orchestrates TEL-055, TEL-002, TEL-033 and the post-creation hand-off to TEL-056 / TEL-010.
@MainActor
@Observable
final class InitialOnboardingViewModel {
    private let grant: CreationGrant
    private let repository: any FamilyRepository
    private let installationProofProvider: any InstallationProofProviding
    private let photoNormalizer: any ProfilePhotoNormalizing
    private let sessionStore: AppSessionStore

    var path: [OnboardingRoute] = []
    var name = ""
    var nickname = ""
    var familyName = ""
    var timeZoneID = FamilyCreationValidation.defaultTimeZoneID
    var isDiscardConfirmationPresented = false
    var generatedInvite: GeneratedInvite?

    private(set) var photo: Data?
    private(set) var members: [DraftMember] = []
    private(set) var nameError: ProfileFieldError?
    private(set) var nicknameError = false
    private(set) var familyNameError: ProfileFieldError?
    private(set) var photoSelectionFailed = false
    private(set) var isCreating = false
    private(set) var banner: CreationBanner?
    private(set) var photoStatus: PhotoStatus = .idle
    private(set) var createdFamily: CreatedFamily?
    private(set) var createdMembers: [UUID: CreatedMember] = [:]
    private(set) var invites: [UUID: MemberInvite] = [:]
    private(set) var invitesInFlight: Set<UUID> = []
    private(set) var isCreatingMembers = false
    private(set) var inviteFailed = false

    private var uploadedMediaID: String?

    var isProfileValid: Bool {
        guard case .success = FamilyCreationValidation.validatedName(name) else {
            return false
        }
        guard case .success = FamilyCreationValidation.validatedNickname(nickname) else {
            return false
        }
        return true
    }

    init(
        grant: CreationGrant,
        repository: any FamilyRepository,
        installationProofProvider: any InstallationProofProviding,
        photoNormalizer: any ProfilePhotoNormalizing,
        sessionStore: AppSessionStore
    ) {
        self.grant = grant
        self.repository = repository
        self.installationProofProvider = installationProofProvider
        self.photoNormalizer = photoNormalizer
        self.sessionStore = sessionStore

        if let draft = sessionStore.onboardingDraft {
            name = draft.name
            nickname = draft.nickname
            photo = draft.photo
            familyName = draft.familyName
            timeZoneID = draft.timeZoneID
            members = draft.members
        }
    }

    var draft: OnboardingDraft {
        OnboardingDraft(
            name: name,
            nickname: nickname,
            photo: photo,
            familyName: familyName,
            timeZoneID: timeZoneID,
            members: members
        )
    }

    var isFamilyCreated: Bool {
        createdFamily != nil
    }

    var hasGeneratedInvite: Bool {
        !invites.isEmpty
    }

    var hasPendingMembers: Bool {
        members.contains { createdMembers[$0.id] == nil }
    }

    // MARK: TEL-055

    func selectPhoto(from data: Data) async {
        do {
            photo = try await photoNormalizer.normalize(data)
            photoSelectionFailed = false
        } catch {
            photoSelectionFailed = true
        }
    }

    func reportPhotoSelectionFailure() {
        photoSelectionFailed = true
    }

    func removePhoto() {
        photo = nil
        photoSelectionFailed = false
    }

    func requestDiscard() {
        isDiscardConfirmationPresented = true
    }

    func discard() {
        sessionStore.discardOnboarding()
    }

    func continueFromProfile() {
        guard validateProfile() else {
            return
        }
        path = [.family]
    }

    // MARK: TEL-033

    /// Adds or updates a local draft member; returns the validation error, if any.
    @discardableResult
    func saveMember(id: UUID?, name rawName: String, role: MemberRole) -> FamilyCreationValidation.TextError? {
        switch FamilyCreationValidation.validatedName(rawName) {
        case let .failure(error):
            return error
        case let .success(memberName):
            if let id, let index = members.firstIndex(where: { $0.id == id }) {
                members[index].name = memberName
                members[index].role = role
            } else {
                members.append(DraftMember(id: UUID(), name: memberName, role: role))
            }
            return nil
        }
    }

    func removeMember(id: UUID) {
        members.removeAll { $0.id == id }
    }

    // MARK: TEL-002

    func goBackToProfile() {
        guard !isFamilyCreated, !isCreating else {
            return
        }
        path = []
    }

    func createFamily() async {
        guard !isCreating, !isFamilyCreated else {
            return
        }
        guard validateProfile() else {
            path = []
            return
        }
        guard validateFamily(),
              case let .success(creatorName) = FamilyCreationValidation.validatedName(name),
              case let .success(creatorNickname) = FamilyCreationValidation.validatedNickname(nickname),
              case let .success(validFamilyName) = FamilyCreationValidation.validatedName(familyName) else {
            return
        }

        isCreating = true
        banner = nil
        defer { isCreating = false }

        let installationProof: String
        do {
            installationProof = try installationProofProvider.installationProof()
        } catch {
            banner = .unavailable
            return
        }

        let created: CreatedFamily
        do {
            created = try await repository.createFamily(
                CreateFamilyCommand(
                    creationGrant: grant.value,
                    creatorName: creatorName,
                    creatorNickname: creatorNickname,
                    familyName: validFamilyName,
                    timeZoneID: timeZoneID
                ),
                installationProof: installationProof
            )
        } catch {
            handleCreationFailure(error)
            return
        }

        createdFamily = created
        sessionStore.establishOnboardingSession(created.session)
        await uploadPhotoThenContinue()
    }

    /// Keeps the draft and returns to TEL-001; a new Apple sign-in either opens the family or issues a new grant.
    func verifyAccess() {
        sessionStore.returnToEntry(preserving: draft)
    }

    // MARK: CA-10 — optional photo after the session exists

    func retryPhoto() async {
        guard photoStatus == .failed, !isCreating else {
            return
        }
        await uploadPhotoThenContinue()
    }

    func skipPhoto() async {
        guard photoStatus == .failed, !isCreating else {
            return
        }
        photoStatus = .idle
        await continueAfterPhoto()
    }

    // MARK: TEL-056

    func retryPendingMembers() async {
        await createPendingMembers()
    }

    func generateInvite(for draftID: UUID) async {
        guard let member = createdMembers[draftID],
              let accessToken,
              !invitesInFlight.contains(draftID) else {
            return
        }
        invitesInFlight.insert(draftID)
        inviteFailed = false
        defer { invitesInFlight.remove(draftID) }

        do {
            let invite = try await repository.issueInvite(memberID: member.id, accessToken: accessToken)
            invites[draftID] = invite
            generatedInvite = GeneratedInvite(draftID: draftID, memberName: member.name, invite: invite)
        } catch {
            inviteFailed = true
        }
    }

    func finishOnboarding() {
        guard let createdFamily else {
            return
        }
        sessionStore.completeOnboarding(profile: createdFamily.session.profile)
    }

    // MARK: Private

    private var accessToken: String? {
        sessionStore.accessToken ?? createdFamily?.session.credentials.token.accessToken
    }

    private func validateProfile() -> Bool {
        switch FamilyCreationValidation.validatedName(name) {
        case .success:
            nameError = nil
        case let .failure(error):
            nameError = error == .required ? .required : .invalid
        }
        switch FamilyCreationValidation.validatedNickname(nickname) {
        case .success:
            nicknameError = false
        case .failure:
            nicknameError = true
        }
        return nameError == nil && !nicknameError
    }

    private func validateFamily() -> Bool {
        switch FamilyCreationValidation.validatedName(familyName) {
        case .success:
            familyNameError = nil
        case let .failure(error):
            familyNameError = error == .required ? .required : .invalid
        }
        guard FamilyCreationValidation.isValidTimeZoneID(timeZoneID) else {
            timeZoneID = FamilyCreationValidation.defaultTimeZoneID
            return false
        }
        return familyNameError == nil
    }

    private func handleCreationFailure(_ error: Error) {
        switch error as? FamilyError {
        case .creationGrantInvalid:
            banner = .creationGrantInvalid
        case .rateLimited:
            banner = .rateLimited
        case let .validationFailed(fieldErrors):
            if fieldErrors["creatorName"] != nil {
                nameError = .invalid
            }
            if fieldErrors["creatorNickname"] != nil {
                nicknameError = true
            }
            if fieldErrors["name"] != nil {
                familyNameError = .invalid
            }
            if fieldErrors["creatorName"] != nil || fieldErrors["creatorNickname"] != nil {
                path = []
            }
            if fieldErrors["timeZoneId"] != nil {
                banner = .unavailable
            }
        case .rejected:
            banner = .unavailable
        case .uncertainOutcome, .network, .unavailable, nil:
            banner = .uncertainOutcome
        }
    }

    private func uploadPhotoThenContinue() async {
        if let photo {
            isCreating = true
            photoStatus = .uploading
            defer { isCreating = false }

            guard let accessToken else {
                photoStatus = .failed
                return
            }
            do {
                let mediaID: String
                if let uploadedMediaID {
                    mediaID = uploadedMediaID
                } else {
                    mediaID = try await repository.uploadProfilePhoto(photo, accessToken: accessToken)
                    uploadedMediaID = mediaID
                }
                try await repository.setProfilePhoto(mediaID: mediaID, accessToken: accessToken)
                photoStatus = .idle
            } catch {
                // The family stays created; the person may retry or continue without the photo.
                photoStatus = .failed
                return
            }
        }
        await continueAfterPhoto()
    }

    private func continueAfterPhoto() async {
        guard !members.isEmpty else {
            finishOnboarding()
            return
        }
        await createPendingMembers()
        path = [.family, .inviteMembers]
    }

    private func createPendingMembers() async {
        guard !isCreatingMembers, let accessToken else {
            return
        }
        isCreatingMembers = true
        defer { isCreatingMembers = false }

        for member in members where createdMembers[member.id] == nil {
            do {
                createdMembers[member.id] = try await repository.createMember(
                    name: member.name,
                    role: member.role,
                    accessToken: accessToken
                )
            } catch {
                // Remaining members stay pending so TEL-056 can offer an explicit retry.
                return
            }
        }
    }
}

struct GeneratedInvite: Identifiable, Equatable {
    let draftID: UUID
    let memberName: String
    let invite: MemberInvite

    var id: UUID { draftID }
}
