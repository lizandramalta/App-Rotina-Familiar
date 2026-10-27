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
            detail = nil
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
            _ = try await repository.decideSignal(id: id, decision: decision, accessToken: token)
            resolved = true
            detail = nil
        } catch {
            // A response may have been lost after a commit. Read the canonical state first.
            do {
                _ = try await repository.getSignalDetail(id: id, accessToken: token)
                failed = true
            } catch KidsSignalError.notFound {
                resolved = true
                detail = nil
            } catch {
                failed = true
            }
        }
    }
}
