import Foundation
import Observation

/// Internal access to TEL-052 from Minhas tarefas, independent of push permission (UX-020 §1, RN65).
/// Shows the most recent result while the following week is in force (E-1). A failed query only
/// hides the card: the daily checklist is never blocked by it.
@MainActor
@Observable
final class WeeklyRecognitionEntryViewModel {
    private let getRecognition: GetOwnWeeklyRecognitionUseCase
    private let now: () -> Date

    private(set) var featured: WeeklyRecognition?

    init(getRecognition: GetOwnWeeklyRecognitionUseCase, now: @escaping () -> Date = Date.init) {
        self.getRecognition = getRecognition
        self.now = now
    }

    func refresh() async {
        do {
            let result = try await getRecognition.featured(now: now())
            guard !Task.isCancelled else { return }
            featured = result
        } catch {
            guard !Task.isCancelled else { return }
            // Keep a confirmed card on transient failures; hide it only when the session is gone.
            if (error as? RecognitionError) == .sessionExpired { featured = nil }
        }
    }
}
