import Foundation
import Observation

/// Photo feedback inside MOD-009. Every case keeps the photo currently shown (SPEC-006 CA-07/08/09).
enum PhotoErrorState: Equatable {
    /// Network/server failure; carries the normalized JPEG so the upload can be retried.
    case uploadFailed(Data)
    case formatUnsupported
    case tooLarge
    case processingNotReady
}

/// Non-blocking banner shown when saving fails; the typed data stays in the form (CA-09).
enum EditorBanner: Equatable {
    case network
    case unavailable
}

/// MOD-009 — Editar meu perfil (SPEC-006, UX-006 §5.2). Adults edit name, label and photo; Kids edit nickname and photo.
@MainActor
@Observable
final class OwnProfileEditorViewModel: Identifiable {
    private let initialProfile: OwnProfile
    private let role: MemberRole
    private let repository: any ProfileRepository
    private let photoNormalizer: any ProfilePhotoNormalizing
    private let sessionStore: AppSessionStore
    private let onSaved: @MainActor (OwnProfile, Data??) -> Void
    private let onDismiss: @MainActor () -> Void

    var name: String {
        didSet { nameRejectedByServer = false }
    }

    var nickname: String {
        didSet { nicknameRejectedByServer = false }
    }

    var isShowingDiscardConfirmation = false

    private(set) var currentAvatarData: Data?
    private(set) var currentMediaID: String?
    private(set) var isUploadingPhoto = false
    private(set) var photoError: PhotoErrorState?
    private(set) var isSaving = false
    private(set) var bannerError: EditorBanner?

    private var nameRejectedByServer = false
    private var nicknameRejectedByServer = false
    private let initialAvatarData: Data?
    private var uploadTask: Task<Void, Never>?

    init(
        initialProfile: OwnProfile,
        initialAvatarData: Data?,
        role: MemberRole,
        repository: any ProfileRepository,
        photoNormalizer: any ProfilePhotoNormalizing,
        sessionStore: AppSessionStore,
        onSaved: @escaping @MainActor (OwnProfile, Data??) -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.initialProfile = initialProfile
        self.initialAvatarData = initialAvatarData
        self.role = role
        self.repository = repository
        self.photoNormalizer = photoNormalizer
        self.sessionStore = sessionStore
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        name = initialProfile.name
        nickname = initialProfile.nickname ?? ""
        currentAvatarData = initialAvatarData
        currentMediaID = initialProfile.photoMediaID
    }

    var isKid: Bool { role == .kid }

    // MARK: Validation and dirty state

    var nameError: FamilyCreationValidation.TextError? {
        guard !isKid else { return nil }
        if case let .failure(error) = ProfileValidation.validatedName(name) { return error }
        return nameRejectedByServer ? .invalidLength : nil
    }

    var nicknameError: FamilyCreationValidation.TextError? {
        if case let .failure(error) = ProfileValidation.validatedNickname(nickname) { return error }
        return nicknameRejectedByServer ? .invalidLength : nil
    }

    var nicknameNonWhitespaceCount: Int { ProfileValidation.nonWhitespaceCount(nickname) }

    var hasUnsavedChanges: Bool {
        if isUploadingPhoto { return true }
        if !isKid, trimmedName != initialProfile.name { return true }
        return trimmedNickname != (initialProfile.nickname ?? "") || currentMediaID != initialProfile.photoMediaID
    }

    var canSave: Bool {
        hasUnsavedChanges && !isSaving && !isUploadingPhoto && nameError == nil && nicknameError == nil
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNickname: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Photo (CA-02, CA-07, CA-08, CA-09)

    func selectPhoto(from rawData: Data) async {
        await beginUpload(raw: rawData, jpeg: nil)
    }

    /// The picker could not deliver the file at all; treated like an unreadable image.
    func reportPhotoSelectionFailure() {
        photoError = .formatUnsupported
    }

    func retryPhotoUpload() async {
        guard case let .uploadFailed(jpeg) = photoError else { return }
        await beginUpload(raw: nil, jpeg: jpeg)
    }

    func keepCurrentPhoto() {
        photoError = nil
    }

    func cancelPhotoUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        isUploadingPhoto = false
    }

    func removePhoto() {
        cancelPhotoUpload()
        currentMediaID = nil
        currentAvatarData = nil
        photoError = nil
    }

    /// Normalization and upload run in one cancellable task, flagged as uploading from the first instant,
    /// so closing, removing or replacing the photo mid-way can never leave an orphan upload behind.
    private func beginUpload(raw: Data?, jpeg: Data?) async {
        cancelPhotoUpload()
        photoError = nil
        isUploadingPhoto = true

        let task = Task {
            var normalized = jpeg
            do {
                if normalized == nil, let raw {
                    normalized = try await self.photoNormalizer.normalize(raw)
                }
                guard !Task.isCancelled, let payload = normalized else { return }
                guard let accessToken = self.sessionStore.accessToken else {
                    self.photoError = .uploadFailed(payload)
                    return
                }
                let mediaID = try await self.repository.uploadProfilePhoto(payload, accessToken: accessToken)
                guard !Task.isCancelled else { return }
                self.currentMediaID = mediaID
                self.currentAvatarData = payload
            } catch {
                guard !Task.isCancelled else { return }
                switch error {
                case ProfilePhotoError.tooLarge, ProfileError.mediaTooLarge:
                    self.photoError = .tooLarge
                case ProfileError.mediaFormatUnsupported:
                    self.photoError = .formatUnsupported
                default:
                    // Before normalization finished there is nothing to retry: the file itself was refused.
                    self.photoError = normalized.map(PhotoErrorState.uploadFailed) ?? .formatUnsupported
                }
            }
        }
        uploadTask = task
        await task.value
        if uploadTask == task {
            uploadTask = nil
            isUploadingPhoto = false
        }
    }

    // MARK: Save (CA-02, CA-06, CA-07, CA-09, CA-12, CA-13)

    private var command: UpdateOwnProfileCommand {
        // Kids never send `name` (CA-12/CA-14).
        let newName = (!isKid && trimmedName != initialProfile.name) ? trimmedName : nil

        let newNickname: OptionalFieldUpdate<String>
        if trimmedNickname == (initialProfile.nickname ?? "") {
            newNickname = .unchanged
        } else {
            newNickname = trimmedNickname.isEmpty ? .clear : .set(trimmedNickname)
        }

        let newPhoto: OptionalFieldUpdate<String>
        if currentMediaID == initialProfile.photoMediaID {
            newPhoto = .unchanged
        } else if let currentMediaID {
            newPhoto = .set(currentMediaID)
        } else {
            newPhoto = .clear
        }
        return UpdateOwnProfileCommand(name: newName, nickname: newNickname, photoMediaID: newPhoto)
    }

    /// `nil`: photo untouched; `.some(nil)`: removed; `.some(bytes)`: replaced.
    private var avatarUpdate: Data?? {
        if currentMediaID == initialProfile.photoMediaID { return nil }
        return .some(currentAvatarData)
    }

    func save() async {
        guard canSave, let accessToken = sessionStore.accessToken else {
            if canSave { bannerError = .unavailable }
            return
        }
        isSaving = true
        bannerError = nil
        if photoError == .processingNotReady { photoError = nil }
        defer { isSaving = false }

        do {
            let updated = try await repository.updateOwnProfile(command, accessToken: accessToken)
            onSaved(updated, avatarUpdate)
            onDismiss()
        } catch let error as ProfileError {
            apply(error)
        } catch {
            bannerError = .unavailable
        }
    }

    private func apply(_ error: ProfileError) {
        switch error {
        case let .validationFailed(fieldErrors):
            nameRejectedByServer = fieldErrors["name"] != nil
            nicknameRejectedByServer = fieldErrors["nickname"] != nil
            if let codes = fieldErrors["photoMediaId"] {
                if codes.contains("PHOTO_MEDIA_NOT_READY") {
                    photoError = .processingNotReady
                } else {
                    bannerError = .unavailable
                }
            } else if !nameRejectedByServer && !nicknameRejectedByServer {
                bannerError = .unavailable
            }
        case .network:
            bannerError = .network
        default:
            bannerError = .unavailable
        }
    }

    // MARK: Closing (UX-006 §4)

    func requestClose() {
        guard !isSaving else { return }
        if hasUnsavedChanges {
            isShowingDiscardConfirmation = true
        } else {
            onDismiss()
        }
    }

    func confirmDiscard() {
        cancelPhotoUpload()
        isShowingDiscardConfirmation = false
        onDismiss()
    }
}
