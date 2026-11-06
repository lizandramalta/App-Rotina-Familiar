import Foundation
import Observation

enum RewardFieldError: Equatable {
    case required
    case invalid
    case duplicate
}

/// Non-blocking feedback after a failed save (UX-015 §6). Duplicate titles show both this banner
/// and a field error; plain validation failures show only the field error (no banner).
enum RewardItemEditorBanner: Equatable {
    case networkFailure
    case duplicateTitle
    case rejected
}

enum RewardItemEditorOutcome: Equatable {
    case saved(RewardItem)
    /// SPEC-015 §5.4/CA-07 — the modal closes without declaring success; TEL-023 offers a reload.
    case uncertain
}

/// Backs MOD-008 (SPEC-015 Fase 1, CA-02/03/04/07). Always a sheet over TEL-023.
@MainActor
@Observable
final class RewardItemEditorViewModel {
    private let addRewardItem: AddRewardItemUseCase
    private let accessToken: String

    var title = ""
    var details = ""

    private(set) var titleError: RewardFieldError?
    private(set) var detailsError: RewardFieldError?

    private(set) var isSaving = false
    private(set) var banner: RewardItemEditorBanner?
    private(set) var outcome: RewardItemEditorOutcome?

    init(repository: any RewardRepository, accessToken: String) {
        self.addRewardItem = AddRewardItemUseCase(repository: repository)
        self.accessToken = accessToken
    }

    /// UX-015 §5.2: available once the local title isn't empty after `trim`; the backend remains
    /// the authority on every other rule (length, control characters, duplicity).
    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasTypedContent: Bool {
        !title.isEmpty || !details.isEmpty
    }

    /// Public and `async` so both the View (wrapped in its own `Task`) and tests can await it directly.
    func saveIfValid() async {
        guard validate() else {
            return
        }
        await save()
    }

    // MARK: Private

    private func validate() -> Bool {
        switch RewardItemValidation.validatedTitle(title) {
        case .success:
            titleError = nil
        case let .failure(error):
            titleError = error == .required ? .required : .invalid
        }
        switch RewardItemValidation.validatedDetails(details) {
        case .success:
            detailsError = nil
        case .failure:
            detailsError = .invalid
        }
        return titleError == nil && detailsError == nil
    }

    /// Draft fields are never cleared here on failure (CA-03/04, UX-015 §4/§6).
    private func save() async {
        guard case let .success(validatedTitle) = RewardItemValidation.validatedTitle(title),
              case let .success(validatedDetails) = RewardItemValidation.validatedDetails(details) else {
            return
        }

        isSaving = true
        banner = nil
        defer { isSaving = false }

        do {
            let item = try await addRewardItem.execute(
                AddRewardItemCommand(title: validatedTitle, details: validatedDetails),
                accessToken: accessToken
            )
            outcome = .saved(item)
        } catch {
            handleSaveFailure(error)
        }
    }

    private func handleSaveFailure(_ error: Error) {
        switch error as? RewardItemError {
        case .uncertainOutcome:
            outcome = .uncertain
        case .network:
            banner = .networkFailure
        case .titleAlreadyExists:
            titleError = .duplicate
            banner = .duplicateTitle
        case let .validationFailed(fieldErrors):
            if fieldErrors["title"] != nil {
                titleError = .invalid
            }
            if fieldErrors["details"] != nil {
                detailsError = .invalid
            }
        case .insufficientPermissions, .unavailable, nil:
            banner = .rejected
        }
    }
}
