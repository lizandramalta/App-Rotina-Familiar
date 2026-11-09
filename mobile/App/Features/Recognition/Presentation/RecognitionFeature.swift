import Foundation
import Observation

/// Builds the Recognition screens with the session's dependencies (UC19, TEL-052).
@MainActor
final class RecognitionFeature {
    private let repository: any RecognitionRepository
    private let sharing: any HighlightSharing
    private let session: any RecognitionSessionProviding
    let notificationRouter: RecognitionNotificationRouter

    init(
        repository: any RecognitionRepository,
        sharing: any HighlightSharing,
        session: any RecognitionSessionProviding,
        notificationRouter: RecognitionNotificationRouter
    ) {
        self.repository = repository
        self.sharing = sharing
        self.session = session
        self.notificationRouter = notificationRouter
    }

    private var getRecognition: GetOwnWeeklyRecognitionUseCase {
        GetOwnWeeklyRecognitionUseCase(repository: repository, session: session)
    }

    func makeEntryViewModel() -> WeeklyRecognitionEntryViewModel {
        WeeklyRecognitionEntryViewModel(getRecognition: getRecognition)
    }

    func makeViewModel(recognitionID: UUID, audience: RecognitionAudience) -> WeeklyRecognitionViewModel {
        WeeklyRecognitionViewModel(
            recognitionID: recognitionID,
            audience: audience,
            getRecognition: getRecognition,
            sharing: sharing
        )
    }
}

/// Holds the recognition opened from a notification until an authenticated "Minhas tarefas" stack
/// consumes it. Without a valid session it waits for recovery; TEL-052 then revalidates it remotely.
@MainActor
@Observable
final class RecognitionNotificationRouter {
    private(set) var pendingRecognitionID: UUID?

    func receive(_ recognitionID: UUID) {
        pendingRecognitionID = recognitionID
    }

    func consume() -> UUID? {
        defer { pendingRecognitionID = nil }
        return pendingRecognitionID
    }
}

extension AppSessionStore: RecognitionSessionProviding {
    var currentAccessToken: String? { accessToken }

    func recoverAccessToken() async -> String? {
        await refreshAccessToken()
    }
}
