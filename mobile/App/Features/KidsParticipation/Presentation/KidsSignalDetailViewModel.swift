import Foundation
import Observation

/// SPEC-013 CA-02–07: confirmed state alone drives the review UI.
@MainActor
@Observable
final class KidsSignalDetailViewModel {
    private(set) var detail: KidsSignalDetail?
    private(set) var photo: Data?
    private(set) var isLoading = false
    private(set) var isDeciding = false
    private(set) var failed = false
    private(set) var photoFailed = false
    private(set) var resolved = false
    /// UX-013 §4/§7/UX-02: whenever `resolved` fires because of someone ELSE's action (never my own
    /// applied decision), this names which accessible announcement to post — always silent, never a
    /// blocking alert, confirmed by the existing SCRUM-117/CA-06 coverage of the `load()` 404 case.
    private(set) var reconciliationAnnouncement: LocalizedStringResource?

    private let id: UUID
    private let repository: any KidsSignalRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(id: UUID, repository: any KidsSignalRepository, accessTokenProvider: @escaping @MainActor () -> String?) {
        self.id = id
        self.repository = repository
        self.accessTokenProvider = accessTokenProvider
    }

    func load() async {
        guard let token = accessTokenProvider(), !isLoading else { failed = true; return }
        isLoading = true
        failed = false
        defer { isLoading = false }
        do {
            let confirmed = try await repository.getSignalDetail(id: id, accessToken: token)
            detail = confirmed
            if let mediaID = confirmed.photoMediaID {
                do {
                    photo = try await repository.getSignalPhoto(mediaID: mediaID, accessToken: token)
                    photoFailed = false
                } catch {
                    photo = nil
                    photoFailed = true
                }
            }
        } catch KidsSignalError.notFound {
            // UX-013 §4: "outra decisão/conclusão já ocorreu" returns silently, no error alert — the
            // copy table ties this exact string to "carregamento de item removido da fila" (§7).
            detail = nil
            reconciliationAnnouncement = "kidsReview.error.not_found"
            resolved = true
        } catch KidsSignalError.actionNotAllowed {
            detail = nil
            failed = true
        } catch {
            failed = true
        }
    }

    func decide(_ decision: KidsReviewDecision) async {
        guard !isDeciding, !photoFailed, let token = accessTokenProvider(), detail != nil else { return }
        isDeciding = true
        failed = false
        defer { isDeciding = false }
        do {
            let result = try await repository.decideSignal(id: id, decision: decision, accessToken: token)
            // UX-013 §6 `Reconciled`: `applied: false` means this decision arrived too late — someone
            // else already settled it. Still returns to the queue, but silently with an announcement;
            // my own applied decision needs no announcement at all.
            reconciliationAnnouncement = result.applied ? nil : "kidsReview.reconciled"
            resolved = true
            detail = nil
        } catch {
            // A response may have been lost after a commit. Read the canonical state first.
            do {
                _ = try await repository.getSignalDetail(id: id, accessToken: token)
                failed = true
            } catch KidsSignalError.notFound {
                // Also `Reconciled`: someone else fully settled it while my decision was in flight.
                reconciliationAnnouncement = "kidsReview.reconciled"
                resolved = true
                detail = nil
            } catch {
                failed = true
            }
        }
    }
}
