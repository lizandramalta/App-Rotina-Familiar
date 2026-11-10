import Foundation
import Observation

/// TEL-052 — Meu destaque semanal (SPEC-020 CA-07/CA-08, UX-020 §2–§3).
/// Shows only the final server result; sharing is optional, editable and never reported as sent.
@MainActor
@Observable
final class WeeklyRecognitionViewModel {
    enum State: Equatable {
        case loading
        case loaded(WeeklyRecognition)
        case sessionExpired
        case error
    }

    let recognitionID: UUID
    let audience: RecognitionAudience
    private let getRecognition: GetOwnWeeklyRecognitionUseCase
    private let prepareShare = PrepareHighlightShareUseCase()
    private let sharing: any HighlightSharing

    private(set) var state: State = .loading
    /// Editable suggestion (RF64). Prepared once per result; reloads keep the person's edits.
    var message: String = ""
    /// Shown after WhatsApp is missing or could not be opened: only copying is offered (UX-020 §3).
    private(set) var isWhatsAppUnavailable = false
    /// E-4: confirmation after an explicit copy. Never implies the message was sent.
    private(set) var copyConfirmationRevision = 0
    private var didPrepareMessage = false
    private var didRecordOpening = false

    init(
        recognitionID: UUID,
        audience: RecognitionAudience,
        getRecognition: GetOwnWeeklyRecognitionUseCase,
        sharing: any HighlightSharing
    ) {
        self.recognitionID = recognitionID
        self.audience = audience
        self.getRecognition = getRecognition
        self.sharing = sharing
    }

    var recognition: WeeklyRecognition? {
        if case let .loaded(recognition) = state { return recognition }
        return nil
    }

    var canShare: Bool { PrepareHighlightShareUseCase.isShareable(message) }
    var showsWhatsAppAction: Bool { !isWhatsAppUnavailable }
    var showsCopyConfirmation: Bool { copyConfirmationRevision > 0 }

    /// Always revalidates with the server, including when opened from a push (UX-020 §3).
    func load() async {
        if recognition == nil { state = .loading }
        do {
            let result = try await getRecognition(id: recognitionID)
            guard !Task.isCancelled else { return }
            state = .loaded(result)
            if !didPrepareMessage {
                message = prepareShare(for: result)
                didPrepareMessage = true
            }
            isWhatsAppUnavailable = !sharing.canOpenWhatsApp
            await recordOpeningIfNeeded(result)
        } catch {
            guard !Task.isCancelled else { return }
            // A failed reload keeps the confirmed content (UX-020 §3 · Erro).
            guard recognition == nil else { return }
            state = (error as? RecognitionError) == .sessionExpired ? .sessionExpired : .error
        }
    }

    /// Explicit action only (CA-08). Returning from or cancelling WhatsApp changes nothing here.
    func shareOnWhatsApp() async {
        guard canShare, recognition != nil else { return }
        guard sharing.canOpenWhatsApp else {
            isWhatsAppUnavailable = true
            return
        }
        let opened = await sharing.openWhatsApp(text: message)
        if !opened { isWhatsAppUnavailable = true }
    }

    func copyMessage() {
        guard canShare, recognition != nil else { return }
        sharing.copy(text: message)
        copyConfirmationRevision += 1
    }

    private func recordOpeningIfNeeded(_ result: WeeklyRecognition) async {
        guard !didRecordOpening, result.openedAt == nil else { return }
        didRecordOpening = true
        await getRecognition.recordOpening(id: result.id)
    }

    // MARK: Presentation text

    var headline: String {
        guard let recognition else { return "" }
        return recognition.isTie
            ? String(localized: "recognition.tie")
            : String(localized: "recognition.first")
    }

    var periodText: String {
        guard let recognition else { return "" }
        return Self.periodText(for: recognition)
    }

    /// Period, headline (tie or not), points and tasks read in sequence (UX-020 §5).
    var summaryAccessibilityLabel: String {
        guard let recognition else { return "" }
        return String(
            format: String(localized: "recognition.summary_accessibility"),
            periodText,
            headline,
            recognition.points,
            recognition.completedTasks
        )
    }

    static func periodText(for recognition: WeeklyRecognition) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = recognition.timeZone
        formatter.dateFormat = "d MMM"
        return String(
            format: String(localized: "recognition.period"),
            formatter.string(from: recognition.startsAt),
            formatter.string(from: recognition.lastDay)
        )
    }
}
