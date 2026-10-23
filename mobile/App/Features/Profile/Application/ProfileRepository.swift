import Foundation

nonisolated protocol ProfileRepository: Sendable {
    func getOwnProfile(accessToken: String) async throws -> OwnProfile
    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile
    func getOwnBadges(accessToken: String) async throws -> BadgesOverview
    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail
    /// Returns the `mediaId` of a `READY` photo, ready to link through `updateOwnProfile`.
    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String
    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data
}
