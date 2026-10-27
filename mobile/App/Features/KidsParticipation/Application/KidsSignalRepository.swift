import Foundation

/// Port for the Kids signal review (SPEC-013). Only the queue read belongs to TEL-015.
protocol KidsSignalRepository: Sendable {
    /// `GET /v1/kids/signals` — pending signals, oldest first.
    func getReviewQueue(accessToken: String, cursor: String?) async throws -> KidsReviewQueuePage
}
