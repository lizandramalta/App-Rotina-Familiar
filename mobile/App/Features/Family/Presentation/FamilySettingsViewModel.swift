import Foundation
import Combine

@MainActor
final class FamilySettingsViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded(FamilySettings)
        case error(String)
        case accessDenied
    }

    @Published private(set) var state: ViewState = .idle
    @Published var selectedTimeZoneID: String? = nil
    @Published var selectedApplication: TimeZoneApplication = .immediate
    @Published private(set) var isPreviewLoading: Bool = false
    @Published private(set) var preview: TimeZoneChangePreview? = nil
    @Published var isConfirmationPresented: Bool = false
    @Published private(set) var isSubmitting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successNotice: String? = nil

    private let repository: any FamilyRepository
    private let session: ActiveFamilySession
    private let accessTokenProvider: @Sendable () -> String?

    init(
        repository: any FamilyRepository,
        session: ActiveFamilySession,
        accessTokenProvider: @escaping @Sendable () -> String?
    ) {
        self.repository = repository
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    var currentSettings: FamilySettings? {
        if case let .loaded(settings) = state {
            return settings
        }
        return nil
    }

    var canRequestPreview: Bool {
        guard let selected = selectedTimeZoneID, let current = currentSettings else {
            return false
        }
        let isSameAsCurrent = selected == current.timeZoneID
        let isSameAsScheduled = selected == current.scheduledTimeZoneChange?.timeZoneID
        return !isSameAsCurrent && !isSameAsScheduled && !isPreviewLoading && !isSubmitting
    }

    func isTimeZoneDisabled(_ identifier: String) -> Bool {
        guard let current = currentSettings else { return false }
        return identifier == current.timeZoneID || identifier == current.scheduledTimeZoneChange?.timeZoneID
    }

    func isTimeZoneScheduled(_ identifier: String) -> Bool {
        guard let current = currentSettings else { return false }
        return identifier == current.scheduledTimeZoneChange?.timeZoneID
    }

    func isTimeZoneCurrent(_ identifier: String) -> Bool {
        guard let current = currentSettings else { return false }
        return identifier == current.timeZoneID
    }

    func loadSettings() async {
        guard session.role == .administrator else {
            state = .accessDenied
            return
        }

        guard let token = accessTokenProvider() else {
            state = .error("Sessão não autenticada")
            return
        }

        state = .loading
        errorMessage = nil

        do {
            let settings = try await repository.getFamilySettings(accessToken: token)
            state = .loaded(settings)
        } catch FamilyError.actionNotAllowed {
            state = .accessDenied
        } catch FamilyError.network {
            state = .error("Não foi possível conectar. Verifique sua internet.")
        } catch {
            state = .error("Não foi possível carregar as configurações da família.")
        }
    }

    func selectTimeZone(_ id: String) {
        guard !isTimeZoneDisabled(id) else { return }
        selectedTimeZoneID = id
    }

    func requestPreview() async {
        guard canRequestPreview,
              let targetID = selectedTimeZoneID,
              let token = accessTokenProvider() else {
            return
        }

        isPreviewLoading = true
        errorMessage = nil

        do {
            let previewResult = try await repository.previewFamilyTimeZoneChange(
                timeZoneID: targetID,
                application: selectedApplication,
                accessToken: token
            )
            preview = previewResult
            isConfirmationPresented = true
            isPreviewLoading = false
        } catch FamilyError.actionNotAllowed {
            isPreviewLoading = false
            state = .accessDenied
        } catch FamilyError.timeZoneUnchanged {
            isPreviewLoading = false
            errorMessage = "O fuso selecionado já é o vigente na família."
        } catch FamilyError.network {
            isPreviewLoading = false
            errorMessage = "Não foi possível conectar. Verifique sua internet."
        } catch {
            isPreviewLoading = false
            errorMessage = "Não foi possível carregar a prévia da alteração."
        }
    }

    func updateApplicationMode(_ mode: TimeZoneApplication) async {
        guard selectedApplication != mode else { return }
        selectedApplication = mode

        // Refresh preview with the newly selected mode if modal is open
        if isConfirmationPresented,
           let targetID = selectedTimeZoneID,
           let token = accessTokenProvider() {
            do {
                let previewResult = try await repository.previewFamilyTimeZoneChange(
                    timeZoneID: targetID,
                    application: mode,
                    accessToken: token
                )
                preview = previewResult
            } catch {
                // Keep existing preview if refresh fails
            }
        }
    }

    func confirmChange() async {
        guard !isSubmitting,
              let targetID = selectedTimeZoneID,
              let token = accessTokenProvider() else {
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            let updated = try await repository.changeFamilyTimeZone(
                timeZoneID: targetID,
                application: selectedApplication,
                accessToken: token
            )
            state = .loaded(updated)
            selectedTimeZoneID = nil
            preview = nil
            isSubmitting = false
            isConfirmationPresented = false
            successNotice = "Fuso horário alterado com sucesso."
        } catch FamilyError.actionNotAllowed {
            isSubmitting = false
            isConfirmationPresented = false
            state = .accessDenied
        } catch FamilyError.timeZoneUnchanged {
            isSubmitting = false
            errorMessage = "O fuso selecionado já é o vigente na família."
        } catch FamilyError.network {
            isSubmitting = false
            errorMessage = "Não foi possível conectar. Verifique sua internet."
        } catch {
            isSubmitting = false
            errorMessage = "Não foi possível confirmar a alteração do fuso."
        }
    }

    func cancelConfirmation() {
        isConfirmationPresented = false
        preview = nil
        errorMessage = nil
    }
}
